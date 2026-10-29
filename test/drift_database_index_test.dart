import 'package:drift/native.dart';
import 'package:network_tools/src/database/drift_database.dart';
import 'package:test/test.dart';

void main() {
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
          "WHERE type = 'index' AND name IN "
          "('idx_vendor_mac_prefix', 'idx_arp_ip_address')",
        )
        .get();

    expect(
      rows.map((row) => row.read<String>('name')),
      containsAll(<String>['idx_vendor_mac_prefix', 'idx_arp_ip_address']),
    );
  });

  test('ensureIndexes can be called repeatedly', () async {
    await database.ensureIndexes();
    await database.ensureIndexes();

    final rows = await database
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'index' AND name = 'idx_vendor_mac_prefix'",
        )
        .get();

    expect(rows, hasLength(1));
  });
}
