import 'dart:io';
import 'dart:typed_data';

import 'package:network_tools/src/device_info/vendor_index.dart';
import 'package:test/test.dart';

import '../tool/build_vendor_index.dart';

/// Guards the committed vendor payload against the CSV it is built from.
///
/// `tool/build_vendor_index.dart` runs by hand (or in CI), never as a build
/// hook, so the shipped bytes are ordinary source that a cold build is
/// guaranteed to compile. That makes the CSV the only place a vendor change
/// needs to be made, and this suite the thing that fails if someone forgets to
/// regenerate.
void main() {
  final csvFile = File('lib/assets/mac-vendors-export.csv');

  late PackedVendorIndex index;

  setUpAll(() {
    index = vendorIndex;
  });

  group('committed vendor index', () {
    test('decodes and is populated', () {
      expect(index.length, greaterThan(30000));
    });

    test('all prefixes are uppercase hex of an IEEE block length', () {
      for (final prefix in index.prefixes) {
        expect(
          prefix,
          matches(RegExp(r'^(?:[0-9A-F]{6}|[0-9A-F]{7}|[0-9A-F]{9})$')),
          reason:
              'Prefix $prefix should be a 6, 7 or 9 character uppercase '
              'hex block prefix (MA-L, MA-M or MA-S/IAB)',
        );
      }
    });

    test('contains known MAC vendor entries', () {
      expect(index.entryFor('000000')?.name, contains('XEROX'));
      expect(index.entryFor('1C8776D')?.name, 'Qivivo');
      expect(index.entryFor('001BC5002')?.name, 'GORAMO - Janusz Gorecki');
      expect(index.entryFor('0050C2000')?.name, 'T.L.S. Corp.');
    });

    test('a sub-block is registered apart from the MA-L block holding it', () {
      expect(
        index.entryFor('001BC5002')?.name,
        isNot(index.entryFor('001BC5')?.name),
        reason: 'A sub-block must not inherit its parent assignment',
      );
    });

    test('every entry carries the four CSV columns', () {
      for (final prefix in index.prefixes) {
        final entry = index.entryFor(prefix)!;
        expect(entry.name, isNotEmpty, reason: 'Vendor for $prefix');
        expect(entry.private, isNotNull);
        expect(entry.blockType, isNotNull);
        expect(entry.lastUpdate, isNotNull);
        expect(entry.prefix, prefix);
      }
    });
  });

  group('committed index matches the CSV', () {
    late Uint8List rebuilt;

    setUpAll(() {
      if (!csvFile.existsSync()) {
        markTestSkipped(
          'CSV not present (excluded from the published '
          'package); run this suite from the repository instead.',
        );
      }
      rebuilt = buildVendorIndex(parseRows(csvFile.readAsStringSync()));
    });

    test('byte for byte', () {
      if (!csvFile.existsSync()) return;
      expect(
        _firstDifference(index.packedBytes, rebuilt),
        isNull,
        reason:
            'lib/src/device_info/vendor_index.data.dart is stale. Run '
            '`dart run tool/build_vendor_index.dart` and commit the result.',
      );
    });

    test('entry counts agree', () {
      if (!csvFile.existsSync()) return;
      expect(
        index.length,
        equals(parseRows(csvFile.readAsStringSync()).length),
      );
    });

    test('every CSV prefix resolves to the same row through the reader', () {
      if (!csvFile.existsSync()) return;
      final expected = {
        for (final row in parseRows(csvFile.readAsStringSync())) row[0]: row,
      };
      expect(index.prefixes.toSet(), equals(expected.keys.toSet()));
      final reference = PackedVendorIndex.fromBytes(rebuilt);
      for (final entry in expected.entries) {
        // Two fillers so both the 9-digit exact match and the cascade down to
        // the parent block are exercised.
        for (final filler in ['F', '0']) {
          final hex = entry.key.padRight(12, filler);
          final got = index.entryFor(hex)!;
          final want = reference.entryFor(hex)!;
          expect(
            (got.name, got.private, got.blockType, got.lastUpdate),
            equals((want.name, want.private, want.blockType, want.lastUpdate)),
            reason: 'Mismatch for $hex',
          );
        }
      }
    });
  });
}

/// The index is ~1.3 MB, so compare it with plain byte reads rather than a
/// deep matcher, which takes a minute to walk that many elements.
String? _firstDifference(Uint8List a, Uint8List b) {
  if (a.length != b.length) {
    return 'length ${a.length} != ${b.length}';
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return 'byte $i: ${a[i]} != ${b[i]}';
  }
  return null;
}
