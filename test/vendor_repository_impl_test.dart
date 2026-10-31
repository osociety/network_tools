import 'package:network_tools/src/device_info/vendor_map.dart';
import 'package:network_tools/src/repository/vendor_repository_impl.dart';
import 'package:test/test.dart';

void main() {
  late VendorRepository repository;

  setUp(() {
    repository = VendorRepository();
  });

  group('VendorRepository', () {
    test('build completes without error', () async {
      await expectLater(repository.build(), completes);
    });

    test('entries returns all MAC prefixes from the generated map', () async {
      final result = await repository.entries();
      expect(result, isNotEmpty);
      expect(result.length, kVendorMap.length);
    });

    test('entryFor returns Vendor if prefix is in the map', () async {
      // Pick the first known prefix from the generated map.
      final knownPrefix = kVendorMap.keys.first;
      final result = await repository.entryFor(knownPrefix);
      expect(result, isNotNull);
      expect(result!.macPrefix, knownPrefix);
      expect(result.vendorName, kVendorMap[knownPrefix]!.$1);
    });

    test('entryFor normalizes MAC addresses with separators', () async {
      final knownPrefix = kVendorMap.keys.first;
      // Format as colon-separated MAC (prefix + extra bytes).
      final mac =
          '${knownPrefix[0]}${knownPrefix[1]}:'
          '${knownPrefix[2]}${knownPrefix[3]}:'
          '${knownPrefix[4]}${knownPrefix[5]}:'
          'dd:ee:ff';
      final result = await repository.entryFor(mac);
      expect(result, isNotNull);
      expect(result!.macPrefix, knownPrefix);
    });

    test('entryFor returns null for unknown prefix', () async {
      final result = await repository.entryFor('FF:FF:FF:00:00:00');
      // FF:FF:FF might or might not be in the map; use a clearly invalid one.
      if (!kVendorMap.containsKey('FFFFFF')) {
        expect(result, isNull);
      }
    });

    test('clear returns true', () async {
      final result = await repository.clear();
      expect(result, isTrue);
    });

    test('close completes without error', () async {
      await expectLater(repository.close(), completes);
    });
  });
}
