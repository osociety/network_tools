import 'dart:io';

import 'package:drift/native.dart';
import 'package:logging/logging.dart';
import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/database/drfit_database_service.dart';
import 'package:network_tools/src/database/drift_database.dart';
import 'package:network_tools/src/injection.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDirectory;
  late AppDatabase database;

  setUp(() async {
    await getIt.reset();
    tempDirectory = await Directory.systemTemp.createTemp('network_tools_cfg_');
    database = AppDatabase(NativeDatabase.memory());
    DriftDatabaseService.appDatabase = database;

    // Seed the vendor table so configuration never downloads the CSV, and add
    // a stale ARP entry that rebuildData should clear.
    await database
        .into(database.vendorDrift)
        .insert(
          VendorDriftCompanion.insert(
            macPrefix: 'AABBCC',
            vendorName: 'Test Vendor',
            private: 'false',
            blockType: 'MA-L',
            lastUpdate: '2024-01-01',
          ),
        );
    await database
        .into(database.aRPDrift)
        .insert(
          ARPDriftCompanion.insert(
            iPAddress: '10.9.9.9',
            macAddress: 'aa:bb:cc:dd:ee:ff',
            hostname: 'stale-host',
            interfaceName: 'en0',
            interfaceType: 'ether',
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
        );
  });

  tearDown(() async {
    await database.close();
    if (tempDirectory.existsSync()) {
      tempDirectory.deleteSync(recursive: true);
    }
  });

  test(
    'configures the package, rebuilds data and logs through the debug listener',
    () async {
      await configureNetworkTools(
        tempDirectory.path,
        enableDebugging: true,
        rebuildData: true,
      );

      expect(dbDirectory, tempDirectory.path);
      expect(enableDebugging, isTrue);
      expect(currentEnv, Env.prod);

      final arpRows = await database.select(database.aRPDrift).get();
      expect(arpRows.map((row) => row.iPAddress), isNot(contains('10.9.9.9')));

      final vendorRows = await database.select(database.vendorDrift).get();
      expect(vendorRows.single.macPrefix, 'AABBCC');

      // Exercise the debug log listener installed by configureNetworkTools.
      Logger('configure_network_tools').fine('listener exercise');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    },
  );
}
