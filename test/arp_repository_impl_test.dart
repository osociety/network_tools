// dart

import 'package:drift/native.dart';
import 'package:network_tools/src/database/database_service.dart';
import 'package:network_tools/src/database/drift_database.dart';
import 'package:network_tools/src/repository/arp_repository_impl.dart';
import 'package:test/test.dart';

// Minimal DatabaseService for testing (no implements)
class TestDatabaseService extends DatabaseService<AppDatabase> {
  TestDatabaseService(this.db);
  final AppDatabase db;
  @override
  Future<AppDatabase?> open() async => db;
}

void main() {
  late AppDatabase realDb;
  late ARPRepository repository;

  setUp(() {
    realDb = AppDatabase(NativeDatabase.memory());
    repository = ARPRepository(TestDatabaseService(realDb));
  });

  tearDown(() async {
    await realDb.close();
  });

  group('ARPRepository', () {
    test('build skips if entries exist', () async {
      // Insert a fake entry
      await realDb
          .into(realDb.aRPDrift)
          .insert(
            ARPDriftCompanion.insert(
              iPAddress: '1.2.3.4',
              macAddress: 'aa:bb:cc:dd:ee:ff',
              hostname: 'host',
              interfaceName: 'eth0',
              interfaceType: 'ether',
              createdAt: DateTime.now(),
            ),
          );
      await repository.build();
      final count = await realDb.select(realDb.aRPDrift).get();
      expect(count.length, 1);
    });

    test('build inserts ARP entries if no entries exist', () async {
      // Patch ARPTableHelper().buildTable() if needed
      await repository.build();
      final count = await realDb.select(realDb.aRPDrift).get();
      expect(count, isNotEmpty);
    });

    test('entries returns list of IP addresses', () async {
      await realDb
          .into(realDb.aRPDrift)
          .insert(
            ARPDriftCompanion.insert(
              iPAddress: '1.2.3.4',
              macAddress: 'aa:bb:cc:dd:ee:ff',
              hostname: 'host',
              interfaceName: 'eth0',
              interfaceType: 'ether',
              createdAt: DateTime.now(),
            ),
          );
      await realDb
          .into(realDb.aRPDrift)
          .insert(
            ARPDriftCompanion.insert(
              iPAddress: '5.6.7.8',
              macAddress: '11:22:33:44:55:66',
              hostname: 'host2',
              interfaceName: 'eth1',
              interfaceType: 'ether',
              createdAt: DateTime.now(),
            ),
          );
      final result = await repository.entries();
      expect(result, containsAll(['1.2.3.4', '5.6.7.8']));
    });

    test('entryFor returns ARPData if found', () async {
      await realDb
          .into(realDb.aRPDrift)
          .insert(
            ARPDriftCompanion.insert(
              iPAddress: '1.2.3.4',
              macAddress: 'aa:bb:cc:dd:ee:ff',
              hostname: 'host',
              interfaceName: 'eth0',
              interfaceType: 'ether',
              createdAt: DateTime.now(),
            ),
          );
      final result = await repository.entryFor('1.2.3.4');
      expect(result, isNotNull);
      expect(result!.iPAddress, '1.2.3.4');
    });

    test('entryFor returns null if not found', () async {
      final result = await repository.entryFor('9.9.9.9');
      expect(result, isNull);
    });

    test('clear deletes entries older than 1 hour', () async {
      final oldDate = DateTime.now().subtract(const Duration(hours: 2));
      await realDb
          .into(realDb.aRPDrift)
          .insert(
            ARPDriftCompanion.insert(
              iPAddress: '1.2.3.4',
              macAddress: 'aa:bb:cc:dd:ee:ff',
              hostname: 'host',
              interfaceName: 'eth0',
              interfaceType: 'ether',
              createdAt: oldDate,
            ),
          );
      final result = await repository.clear();
      expect(result, isTrue);
      final count = await realDb.select(realDb.aRPDrift).get();
      expect(count, isEmpty);
    });

    test('clear returns false if no entries', () async {
      final result = await repository.clear();
      expect(result, isFalse);
    });
  });
}
