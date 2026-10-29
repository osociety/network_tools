import 'package:drift/native.dart';
import 'package:network_tools/src/database/drfit_database_service.dart';
import 'package:network_tools/src/database/drift_database.dart';
import 'package:test/test.dart';

class _FailingIndexDatabase extends AppDatabase {
  _FailingIndexDatabase() : super(NativeDatabase.memory());

  @override
  Future<void> ensureIndexes() => throw StateError('index creation failed');
}

void main() {
  test(
    'open survives index creation failures and caches the database',
    () async {
      final database = _FailingIndexDatabase();
      DriftDatabaseService.appDatabase = database;

      final service = DriftDatabaseService();
      final opened = await service.open();

      expect(opened, same(database));
      expect(await service.open(), same(database));
    },
  );
}
