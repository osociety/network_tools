import 'dart:convert';
import 'dart:typed_data';

import 'package:network_tools/src/device_info/vendor_index.data.dart';
import 'package:network_tools/src/device_info/vendor_index_layout.dart';
import 'package:universal_io/io.dart';

/// One row of the vendor index.
typedef VendorIndexEntry = ({
  String blockType,
  String lastUpdate,
  String name,
  String prefix,
  String private,
});

/// Read-only view over the packed MAC vendor index.
///
/// The payload is decoded once, on first use, and lookups are binary searches
/// over the decoded bytes: no per-entry Dart objects are ever materialised.
class PackedVendorIndex {
  PackedVendorIndex._(this._bytes) : _data = ByteData.sublistView(_bytes) {
    if (_data.getUint32(0, Endian.little) != kVendorIndexMagic ||
        _data.getUint32(4, Endian.little) != kVendorIndexFormatVersion) {
      throw StateError(
        'The packed vendor index in vendor_index.data.dart does not match '
        'this reader. Run `dart run tool/build_vendor_index.dart`.',
      );
    }
    _n6 = _data.getUint32(8, Endian.little);
    _n7 = _data.getUint32(12, Endian.little);
    _n9 = _data.getUint32(16, Endian.little);
    _maL = _data.getUint32(20, Endian.little);
    _maM = _data.getUint32(24, Endian.little);
    _sub = _data.getUint32(28, Endian.little);
    _names = _data.getUint32(32, Endian.little);
    _dates = _data.getUint32(36, Endian.little);
    _readDateTable();
  }

  /// Decodes an already inflated payload, as built by
  /// `tool/build_vendor_index.dart`. Used by the parity test to compare the
  /// committed bytes against a fresh CSV build.
  PackedVendorIndex.fromBytes(Uint8List bytes) : this._(bytes);

  /// Decodes the shipped payload. Costs roughly ten milliseconds; see
  /// [vendorIndex] for the cached instance.
  factory PackedVendorIndex.decode() {
    final gzipped = base64.decode(kVendorIndexBase64);
    return PackedVendorIndex._(Uint8List.fromList(gzip.decode(gzipped)));
  }

  final Uint8List _bytes;
  final ByteData _data;

  late final int _n6;
  late final int _n7;
  late final int _n9;
  late final int _maL;
  late final int _maM;
  late final int _sub;
  late final int _names;
  late final int _dates;
  final List<String> _dateValues = [];

  /// The inflated payload bytes, exposed for the parity test.
  Uint8List get packedBytes => _bytes;

  /// Number of assignable prefixes in the index.
  int get length => _n6 + _n7 + _n9;

  void _readDateTable() {
    var p = _sub + _n9 * kVendorIndexLongRecordSize;
    final count = _data.getUint16(p, Endian.little);
    p += 2;
    for (var i = 0; i < count; i++) {
      final start = _dates + _data.getUint16(p + i * 2, Endian.little);
      _dateValues.add(_utf8At(start));
    }
  }

  String _utf8At(int start) {
    var end = start;
    while (_bytes[end] != 0) {
      end++;
    }
    return _utf8Decoder.convert(_bytes, start, end);
  }

  /// Longest match wins: an MA-S, MA-M or IAB sub-block is registered to its
  /// own vendor even when the MA-L block containing it is not.
  ///
  /// [hex] is an upper-case, separator-free MAC address as produced by
  /// `VendorTable.normalizedHex`.
  VendorIndexEntry? entryFor(String hex) {
    if (hex.length >= 9) {
      final entry = _probeLong(hex);
      if (entry != null) return entry;
    }
    if (hex.length >= 7) {
      final entry = _probeFixed(_maM, _n7, hex.substring(0, 7));
      if (entry != null) return entry;
    }
    if (hex.length >= 6) {
      return _probeFixed(_maL, _n6, hex.substring(0, 6));
    }
    return null;
  }

  VendorIndexEntry? _probeLong(String hex) {
    final top = int.parse(hex.substring(0, 8), radix: 16);
    final last = _hexValue(hex.codeUnitAt(8));
    var low = 0;
    var high = _n9 - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final p = _sub + mid * kVendorIndexLongRecordSize;
      final key = _data.getUint32(p, Endian.little);
      if (top < key) {
        high = mid - 1;
      } else if (top > key) {
        low = mid + 1;
      } else {
        final digit = _data.getUint8(p + 4);
        if (last < digit) {
          high = mid - 1;
        } else if (last > digit) {
          low = mid + 1;
        } else {
          return _entry(p + 5, p + 9, hex.substring(0, 9));
        }
      }
    }
    return null;
  }

  VendorIndexEntry? _probeFixed(int section, int count, String prefix) {
    if (count == 0) return null;
    final key = int.parse(prefix, radix: 16);
    var low = 0;
    var high = count - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final p = section + mid * kVendorIndexRecordSize;
      final value = _data.getUint32(p, Endian.little);
      if (key < value) {
        high = mid - 1;
      } else if (key > value) {
        low = mid + 1;
      } else {
        return _entry(p + 4, p + 8, prefix);
      }
    }
    return null;
  }

  VendorIndexEntry _entry(int valueOffset, int metaOffset, String prefix) => (
    prefix: prefix,
    name: _utf8At(_data.getUint32(valueOffset, Endian.little) + _names),
    private: kVendorPrivateCodes[_data.getUint8(metaOffset)],
    blockType: kVendorBlockTypeCodes[_data.getUint8(metaOffset + 1)],
    lastUpdate: _dateValues[_data.getUint16(metaOffset + 2, Endian.little)],
  );

  /// Every assignable prefix in the index, upper-case hex, six, seven then
  /// nine characters long.
  Iterable<String> get prefixes => _prefixes();

  Iterable<String> _prefixes() sync* {
    for (var i = 0; i < _n6; i++) {
      yield _hex(
        _data.getUint32(_maL + i * kVendorIndexRecordSize, Endian.little),
        6,
      );
    }
    for (var i = 0; i < _n7; i++) {
      yield _hex(
        _data.getUint32(_maM + i * kVendorIndexRecordSize, Endian.little),
        7,
      );
    }
    for (var i = 0; i < _n9; i++) {
      final p = _sub + i * kVendorIndexLongRecordSize;
      // MA-S/IAB keys are stored as the first eight hex digits plus the ninth.
      yield _hex(
        (_data.getUint32(p, Endian.little) << 4) | _data.getUint8(p + 4),
        9,
      );
    }
  }

  String _hex(int value, int width) =>
      value.toRadixString(16).padLeft(width, '0').toUpperCase();
}

int _hexValue(int codeUnit) {
  if (codeUnit >= 0x30 && codeUnit <= 0x39) return codeUnit - 0x30; // 0-9
  if (codeUnit >= 0x41 && codeUnit <= 0x46) return codeUnit - 0x37; // A-F
  return codeUnit - 0x57; // a-f
}

const _utf8Decoder = Utf8Decoder(allowMalformed: true);

PackedVendorIndex? _vendorIndexInstance;

/// The vendor index, decoded on first access and cached for the isolate.
PackedVendorIndex get vendorIndex =>
    _vendorIndexInstance ??= PackedVendorIndex.decode();
