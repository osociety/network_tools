import 'dart:io';

import 'package:network_tools/src/device_info/vendor_map.dart';
import 'package:test/test.dart';

void main() {
  group('Build hook generates vendor_map.dart correctly', () {
    test('kVendorMap is not empty', () {
      expect(kVendorMap, isNotEmpty);
      expect(kVendorMap.length, greaterThan(30000));
    });

    test('all keys are 6-character uppercase hex strings', () {
      for (final key in kVendorMap.keys) {
        expect(key, hasLength(6), reason: 'Key $key should be 6 characters');
        expect(
          key,
          matches(RegExp(r'^[0-9A-F]{6}$')),
          reason: 'Key $key should be uppercase hex',
        );
      }
    });

    test('all values are 4-tuple records with non-empty vendor names', () {
      for (final entry in kVendorMap.entries) {
        final value = entry.value;
        expect(
          value.$1,
          isNotEmpty,
          reason: 'Vendor name for ${entry.key} should not be empty',
        );
        expect(value.$2, isNotNull, reason: 'Private field for ${entry.key}');
        expect(
          value.$3,
          isNotNull,
          reason: 'Block type field for ${entry.key}',
        );
        expect(
          value.$4,
          isNotNull,
          reason: 'Last update field for ${entry.key}',
        );
      }
    });

    test('contains known MAC vendor entries', () {
      expect(kVendorMap.containsKey('000000'), isTrue);
      expect(kVendorMap['000000']!.$1, contains('XEROX'));
    });

    test('map is sorted by key', () {
      final keys = kVendorMap.keys.toList();
      final sortedKeys = List<String>.from(keys)..sort();
      expect(
        keys,
        equals(sortedKeys),
        reason: 'Keys should be in sorted order',
      );
    });

    test('entry count matches CSV parsing', () {
      final csvFile = File('lib/assets/mac-vendors-export.csv');
      if (!csvFile.existsSync()) {
        markTestSkipped(
          'CSV file not available (excluded from published package)',
        );
      }

      final lines = csvFile.readAsLinesSync();
      final expectedEntries = <String>{};

      for (var i = 1; i < lines.length; i++) {
        final row = _parseCsvLine(lines[i]);
        if (row.length < 2) continue;

        final prefix = row[0]
            .replaceAll(RegExp('[^0-9a-fA-F]'), '')
            .toUpperCase();
        if (prefix.length != 6) continue;

        final vendorName = row[1].trim();
        if (vendorName.isEmpty) continue;

        expectedEntries.add(prefix);
      }

      expect(
        kVendorMap.length,
        equals(expectedEntries.length),
        reason: 'Generated map should have same count as valid CSV entries',
      );
    });
  });
}

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
    } else {
      if (ch == '"') {
        inQuotes = true;
      } else if (ch == ',') {
        fields.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
  }
  fields.add(buf.toString());
  return fields;
}
