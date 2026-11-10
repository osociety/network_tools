// Regenerates `lib/src/device_info/vendor_index.data.dart` from the IEEE
// assignment export at `lib/assets/mac-vendors-export.csv`.
//
// Run: dart run tool/build_vendor_index.dart
//
// The CSV is the source of truth and stays in the repository; the generated
// Dart file is what ships, so a consumer build never needs the network or a
// code generator. `test/vendor_index_parity_test.dart` fails if the two drift.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../lib/src/device_info/vendor_index_layout.dart';

void main() {
  final csvFile = File(_join('lib', 'assets', 'mac-vendors-export.csv'));
  if (!csvFile.existsSync()) {
    stderr.writeln('CSV not found at ${csvFile.path}');
    exit(1);
  }
  final rows = parseRows(csvFile.readAsStringSync());
  final packed = buildVendorIndex(rows);
  final gzipped = GZipCodec().encode(packed);
  final outFile = File(
    _join('lib', 'src', 'device_info', 'vendor_index.data.dart'),
  );
  outFile.writeAsStringSync(_emitDart(gzipped));
  stdout.writeln(
    'Generated ${outFile.path}: ${rows.length} rows -> ${packed.length} B '
    'packed, ${gzipped.length} B gzipped, '
    '${(outFile.statSync().size / 1024).round()} KB Dart source',
  );
}

/// Every assignable row: a 6, 7 or 9 hex-character prefix plus its four
/// fields, in CSV order.
List<List<String>> parseRows(String csvContent) {
  final lines = csvContent.split('\n');
  if (lines.isEmpty) throw const FormatException('CSV is empty');
  final rows = <List<String>>[];
  for (var i = 1; i < lines.length; i++) {
    final row = _parseCsvLine(lines[i].trimRight());
    if (row.length < 2) continue;
    final prefix = _normalizeHex(row[0]);
    if (!kVendorPrefixLengths.contains(prefix.length)) continue;
    final vendorName = row[1].trim();
    if (vendorName.isEmpty) continue;
    rows.add([
      prefix,
      vendorName,
      _field(row, 2),
      _field(row, 3),
      _field(row, 4),
    ]);
  }
  return rows;
}

String _field(List<String> row, int index) =>
    row.length > index ? row[index].trim() : '';

/// Packs rows into the byte format documented in `vendor_index_layout.dart`.
Uint8List buildVendorIndex(List<List<String>> rows) {
  final nameOffsets = <String, int>{};
  final dateIndexes = <String, int>{};
  final names = BytesBuilder(copy: false);
  final byLength = <int, List<_Record>>{6: [], 7: [], 9: []};

  for (final row in rows) {
    final prefix = row[0];
    final name = row[1];
    final nameOffset = nameOffsets.putIfAbsent(name, () {
      final at = names.length;
      final bytes = utf8.encode(name);
      names.add(bytes);
      names.addByte(0);
      return at;
    });
    final dateIndex = dateIndexes.putIfAbsent(row[4], () => dateIndexes.length);
    final record = _Record(
      key: int.parse(prefix, radix: 16),
      nameOffset: nameOffset,
      privateCode: kVendorPrivateCodes.indexOf(row[2]),
      blockCode: kVendorBlockTypeCodes.indexOf(row[3]),
      dateIndex: dateIndex,
    );
    if (record.privateCode < 0 || record.blockCode < 0) {
      throw StateError('Unexpected column value in row: $row');
    }
    byLength[prefix.length]!.add(record);
  }
  final nameBlob = names.toBytes();
  if (dateIndexes.length > 0xFFFF) {
    throw StateError('Too many distinct dates for a 16 bit index.');
  }

  for (final list in byLength.values) {
    list.sort((a, b) => a.key.compareTo(b.key));
  }
  final n6 = byLength[6]!.length;
  final n7 = byLength[7]!.length;
  final n9 = byLength[9]!.length;

  final dateList = dateIndexes.keys.toList();
  final dateBlob = BytesBuilder(copy: false);
  for (final date in dateList) {
    dateBlob.add(utf8.encode(date));
    dateBlob.addByte(0);
  }
  final dateBytes = dateBlob.toBytes();

  const maL = kVendorIndexHeaderSize;
  final maM = maL + n6 * kVendorIndexRecordSize;
  final sub = maM + n7 * kVendorIndexRecordSize;
  final dateTable = sub + n9 * kVendorIndexLongRecordSize;
  final dateTableSize = 2 + dateList.length * 2;
  final nameDict = dateTable + dateTableSize;
  final dateDict = nameDict + nameBlob.length;
  final total = dateDict + dateBytes.length;

  final bytes = Uint8List(total);
  final data = ByteData.sublistView(bytes);
  data.setUint32(0, kVendorIndexMagic, Endian.little);
  data.setUint32(4, kVendorIndexFormatVersion, Endian.little);
  data.setUint32(8, n6, Endian.little);
  data.setUint32(12, n7, Endian.little);
  data.setUint32(16, n9, Endian.little);
  data.setUint32(20, maL, Endian.little);
  data.setUint32(24, maM, Endian.little);
  data.setUint32(28, sub, Endian.little);
  data.setUint32(32, nameDict, Endian.little);
  data.setUint32(36, dateDict, Endian.little);

  var p = maL;
  for (final record in byLength[6]!) {
    _writeShort(data, p, record);
    p += kVendorIndexRecordSize;
  }
  p = maM;
  for (final record in byLength[7]!) {
    _writeShort(data, p, record);
    p += kVendorIndexRecordSize;
  }
  p = sub;
  for (final record in byLength[9]!) {
    // Nine hex digits is 36 bits: the first eight go in a 32 bit word, the
    // ninth in the byte after it, so the section stays binary searchable on
    // (top, last) in the same order as the full key.
    data.setUint32(p, record.key >> 4, Endian.little);
    data.setUint8(p + 4, record.key & 0xF);
    data.setUint32(p + 5, record.nameOffset, Endian.little);
    data.setUint8(p + 9, record.privateCode);
    data.setUint8(p + 10, record.blockCode);
    data.setUint16(p + 11, record.dateIndex, Endian.little);
    p += kVendorIndexLongRecordSize;
  }
  data.setUint16(dateTable, dateList.length, Endian.little);
  var accumulator = 0;
  for (var i = 0; i < dateList.length; i++) {
    data.setUint16(dateTable + 2 + i * 2, accumulator, Endian.little);
    accumulator += utf8.encode(dateList[i]).length + 1;
  }
  bytes.setRange(nameDict, nameDict + nameBlob.length, nameBlob);
  bytes.setRange(dateDict, dateDict + dateBytes.length, dateBytes);
  return bytes;
}

void _writeShort(ByteData data, int p, _Record record) {
  data.setUint32(p, record.key, Endian.little);
  data.setUint32(p + 4, record.nameOffset, Endian.little);
  data.setUint8(p + 8, record.privateCode);
  data.setUint8(p + 9, record.blockCode);
  data.setUint16(p + 10, record.dateIndex, Endian.little);
}

class _Record {
  const _Record({
    required this.key,
    required this.nameOffset,
    required this.privateCode,
    required this.blockCode,
    required this.dateIndex,
  });

  final int key;
  final int nameOffset;
  final int privateCode;
  final int blockCode;
  final int dateIndex;
}

/// The generated file is emitted in the shape `dart format` leaves it in, so
/// the payload survives the repository's format-on-commit hook.
String _emitDart(List<int> gzipped) {
  final payload = base64.encode(gzipped);
  // The generated literal is not raw, which base64 guarantees to be safe.
  if (payload.contains(r'$') || payload.contains(r'\')) {
    throw StateError('Unexpected character in the base64 payload.');
  }
  return '''
// GENERATED BY tool/build_vendor_index.dart - DO NOT EDIT.
//
// Source of truth: lib/assets/mac-vendors-export.csv (IEEE SA assignment
// export). Compressed packed MAC vendor index; see vendor_index_layout.dart
// for the byte format and vendor_index.dart for the reader.

/// Gzipped packed vendor index, base64 encoded.
const String kVendorIndexBase64 =
    \'\'\'$payload\'\'\';
''';
}

String _normalizeHex(String value) {
  final out = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    final c = value.codeUnitAt(i);
    if (c >= 0x30 && c <= 0x39 ||
        c >= 0x41 && c <= 0x46 ||
        c >= 0x61 && c <= 0x66) {
      out.writeCharCode(c < 0x61 ? c : c - 0x20); // upper-case a-f
    }
  }
  return out.toString();
}

String _join(String a, String b, [String? c, String? d]) =>
    [a, b, c, d].whereType<String>().join(Platform.pathSeparator);

List<String> _parseCsvLine(String line) {
  final fields = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        buf.write(ch);
      }
    } else if (ch == '"') {
      inQuotes = true;
    } else if (ch == ',') {
      fields.add(buf.toString());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  fields.add(buf.toString());
  return fields;
}
