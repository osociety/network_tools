import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:network_tools/src/database/drift_database.dart';
import 'package:test/test.dart';

void main() {
  // Each test gets its own in-memory database, which drift flags by default.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('ensureIndexes creates lookup indexes', () async {
    await database.ensureIndexes();

    final rows = await database
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'index' AND name = 'idx_arp_ip_address'",
        )
        .get();

    expect(
      rows.map((row) => row.read<String>('name')),
      contains('idx_arp_ip_address'),
    );
  });

  test('ensureIndexes can be called repeatedly', () async {
    await database.ensureIndexes();
    await database.ensureIndexes();

    final rows = await database
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'index' AND name = 'idx_arp_ip_address'",
        )
        .get();

    expect(rows, hasLength(1));
  });
}
