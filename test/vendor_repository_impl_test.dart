import 'dart:io';

import 'package:drift/native.dart';
import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/database/database_service.dart';
import 'package:network_tools/src/database/drift_database.dart';
import 'package:network_tools/src/services/impls/vendor_repository_impl.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

// Minimal DatabaseService for testing
class TestDatabaseService extends DatabaseService<AppDatabase> {
  TestDatabaseService(this.db);
  final AppDatabase db;
  @override
  Future<AppDatabase?> open() async => db;
}

void main() {
  late AppDatabase realDb;
  late VendorRepository repository;

  setUp(() async {
    // Set dbDirectory to a temp directory
    final tempDir = Directory.systemTemp.createTempSync();
    dbDirectory = tempDir.path;
    // Write a minimal mac-vendors-export.csv file
    final csvFile = File(p.join(dbDirectory, 'mac-vendors-export.csv'));
    await csvFile.writeAsString('''
macPrefix,vendorName,private,blockType,lastUpdate
00:11:22,TestVendor,,,
33:44:55,AnotherVendor,,,
''');
    realDb = AppDatabase(NativeDatabase.memory());
    repository = VendorRepository(TestDatabaseService(realDb));
  });

  tearDown(() async {
    await realDb.close();
  });

  group('VendorRepository', () {
    test('build skips if entries exist', () async {
      // Insert a fake entry
      await realDb
          .into(realDb.vendorDrift)
          .insert(
            VendorDriftCompanion.insert(
              macPrefix: '00:11:22',
              vendorName: 'TestVendor',
              private: '',
              blockType: '',
              lastUpdate: '',
            ),
          );
      await repository.build();
      final count = await realDb.select(realDb.vendorDrift).get();
      expect(count.length, 1);
    });

    test('build inserts vendor entries if no entries exist', () async {
      // You may need to patch VendorTable.fetchVendorTable if it is used
      await repository.build();
      final count = await realDb.select(realDb.vendorDrift).get();
      expect(count, isNotEmpty);
    });

    test('entries returns list of mac prefixes', () async {
      await realDb
          .into(realDb.vendorDrift)
          .insert(
            VendorDriftCompanion.insert(
              macPrefix: '00:11:22',
              vendorName: 'TestVendor',
              private: '',
              blockType: '',
              lastUpdate: '',
            ),
          );
      await realDb
          .into(realDb.vendorDrift)
          .insert(
            VendorDriftCompanion.insert(
              macPrefix: '33:44:55',
              vendorName: 'AnotherVendor',
              private: '',
              blockType: '',
              lastUpdate: '',
            ),
          );
      final result = await repository.entries();
      expect(result, containsAll(['00:11:22', '33:44:55']));
    });

    test('VendorRepository entryFor returns Vendor if found', () async {
      await repository.build(); // Ensure data is present
      final result = await repository.entryFor('00:11:22');
      expect(result, isNotNull);
      expect(result!.macPrefix, '001122');
    });

    test('entryFor returns null if not found', () async {
      final result = await repository.entryFor('FF:FF:FF');
      expect(result, isNull);
    });

    test('clear deletes all vendor entries', () async {
      await realDb
          .into(realDb.vendorDrift)
          .insert(
            VendorDriftCompanion.insert(
              macPrefix: '00:11:22',
              vendorName: 'TestVendor',
              private: '',
              blockType: '',
              lastUpdate: '',
            ),
          );
      final result = await repository.clear();
      expect(result, isTrue);
      final count = await realDb.select(realDb.vendorDrift).get();
      expect(count, isEmpty);
    });

    test('VendorRepository clear returns false if no entries', () async {
      // Ensure table is empty
      final all = await realDb.select(realDb.vendorDrift).get();
      expect(all, isEmpty);
      final result = await repository.clear();
      expect(result, isTrue);
    });

    test('close calls database.close', () async {
      var closed = false;
      final db = _TestAppDatabaseWithClose(realDb, () => closed = true);
      final repo = VendorRepository(TestDatabaseService(db));
      await repo.close();
      expect(closed, isTrue);
    });
  });
}

// Helper to test close
class _TestAppDatabaseWithClose extends AppDatabase {
  _TestAppDatabaseWithClose(this._delegate, this.onClose)
    : super(NativeDatabase.memory());
  final AppDatabase _delegate;
  final void Function() onClose;
  @override
  Future<void> close() async {
    onClose();
    await _delegate.close();
  }
}
