import 'package:network_tools/src/device_info/vendor_index.dart';
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
      expect(result.length, vendorIndex.length);
    });

    test('entryFor returns Vendor if prefix is in the map', () async {
      // Pick the first known prefix from the generated map.
      final knownPrefix = vendorIndex.prefixes.first;
      final result = await repository.entryFor(knownPrefix);
      expect(result, isNotNull);
      expect(result!.macPrefix, knownPrefix);
      expect(result.vendorName, vendorIndex.entryFor(knownPrefix)!.name);
    });

    test('entryFor normalizes MAC addresses with separators', () async {
      final knownPrefix = vendorIndex.prefixes.first;
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
      // FF:FF:FF is not an assigned block prefix.
      expect(result, isNull);
    });

    group('entryFor longest-prefix matching', () {
      test(
        'prefers an MA-S sub-block over the MA-L block holding it',
        () async {
          final result = await repository.entryFor('00:1B:C5:00:2:AA:BB');
          expect(result!.macPrefix, '001BC5002');
          expect(result.vendorName, 'GORAMO - Janusz Gorecki');
          expect(result.blockType, 'MA-S');
          expect(
            result.vendorName,
            isNot('IEEE Registration Authority'),
            reason: 'The parent MA-L entry only stands in for its sub-blocks',
          );
        },
      );

      test('matches an MA-M block on 7 hex digits', () async {
        final result = await repository.entryFor('1C:87:76:D5:AA:BB');
        expect(result!.macPrefix, '1C8776D');
        expect(result.vendorName, 'Qivivo');
        expect(result.blockType, 'MA-M');
      });

      test('matches an IAB block on 9 hex digits', () async {
        final result = await repository.entryFor('00:50:C2:00:01:23');
        expect(result!.macPrefix, '0050C2000');
        expect(result.vendorName, 'T.L.S. Corp.');
        expect(result.blockType, 'IAB');
      });

      test('still resolves MA-L prefixes as before', () async {
        final result = await repository.entryFor('00:03:93:AB:CD:EF');
        expect(result!.macPrefix, '000393');
        expect(result.vendorName, 'Apple, Inc.');
      });

      test('falls back to the parent when no sub-block matches', () async {
        final result = await repository.entryFor('00:1B:C5:AA:BB:CC');
        expect(result!.macPrefix, '001BC5');
        expect(result.blockType, 'MA-L');
      });

      test('ignores separators in sub-block lookups', () async {
        final dashed = await repository.entryFor('00-1b-c5-00-2a-ab');
        final raw = await repository.entryFor('001BC5002AAB');
        expect(dashed!.macPrefix, raw!.macPrefix);
      });

      test('returns null for unregistered and truncated input', () async {
        expect(await repository.entryFor('FF:FF:FF:00:00:00'), isNull);
        expect(await repository.entryFor('aabb'), isNull);
      });
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
