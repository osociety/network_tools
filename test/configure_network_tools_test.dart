import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:logging/logging.dart';
import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/database/drfit_database_service.dart';
import 'package:network_tools/src/database/drift_database.dart';
import 'package:network_tools/src/injection.dart';
import 'package:network_tools/src/repository/repository.dart';
import 'package:network_tools/src/services/impls/host_scanner_service_impl.dart';
import 'package:test/test.dart';

/// What a shutdown has to release, as one lifecycle in one isolate.
class _ShutdownRequest {
  _ShutdownRequest({required this.reportTo, required this.dbPath});

  final SendPort reportTo;
  final String dbPath;
}

/// Configures, scans and shuts down, then reports back.
///
/// The isolate's own exit is the observation: it stays alive as long as it owns
/// a resource, so termination proves [closeNetworkTools] released the database
/// connection and the background isolate behind it. No file descriptor counting
/// involved, which keeps the test identical on every platform.
Future<void> _configureScanAndClose(_ShutdownRequest request) async {
  await configureNetworkTools(request.dbPath, buildVendorTable: false);
  await HostScannerServiceImpl()
      .getAllSendablePingableDevices('127.0.0', lastHostId: 1)
      .toList();
  await closeNetworkTools();
  request.reportTo.send('SHUTDOWN-DONE');
}

/// The shutdown isolate opens its database below [directory], and Windows keeps
/// that file locked until the killed isolate is fully gone.
Future<void> _deleteTempDirectory(Directory directory) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    try {
      await directory.delete(recursive: true);
      return;
    } on FileSystemException {
      if (attempt == 29) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}

void main() {
  // Each test gets its own database, which drift flags by default.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory tempDirectory;
  late AppDatabase database;

  setUpAll(() {
    tempDirectory = Directory.systemTemp.createTempSync('network_tools_cfg_');
  });

  // [closeNetworkTools] releases the cached connection and a drift connection
  // cannot be reopened, so the tests may not share one database.
  setUp(() async {
    await getIt.reset();
    database = AppDatabase(NativeDatabase.memory());
    DriftDatabaseService.appDatabase = database;

    // Add a stale ARP entry that rebuildData should clear.
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
    await DriftDatabaseService.appDatabase?.close();
    DriftDatabaseService.reset();
  });

  tearDownAll(() {
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

      // Exercise the debug log listener installed by configureNetworkTools.
      Logger('configure_network_tools').fine('listener exercise');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    },
  );

  test('skips the vendor table for worker isolates', () async {
    await configureNetworkTools(tempDirectory.path, buildVendorTable: false);
    // Vendor lookups now use a const map, so there is no file to check.
    // This test verifies that buildVendorTable: false doesn't crash.
  });

  group('closeNetworkTools', () {
    test('is a no-op before the package was configured', () async {
      DriftDatabaseService.reset();

      await expectLater(closeNetworkTools(), completes);

      expect(DriftDatabaseService.appDatabase, isNull);
    });

    test('releases the database but leaves the package usable', () async {
      await configureNetworkTools(tempDirectory.path, buildVendorTable: false);

      await closeNetworkTools();

      expect(DriftDatabaseService.appDatabase, isNull);
      // Calling it again has nothing left to release.
      await expectLater(closeNetworkTools(), completes);

      // Reading through the repository is what threw
      // `ConnectionClosedException: Channel was closed before receiving a
      // response` while the closed connection stayed cached.
      database = AppDatabase(NativeDatabase.memory());
      DriftDatabaseService.appDatabase = database;
      await configureNetworkTools(tempDirectory.path, buildVendorTable: false);

      expect(await getIt<Repository<ARPData>>().entries(), isNotNull);
    });

    test('does not stack the debug listener when reconfiguring', () async {
      final printed = <String>[];

      await runZoned<Future<void>>(
        () async {
          await configureNetworkTools(
            tempDirectory.path,
            enableDebugging: true,
            buildVendorTable: false,
          );
          await configureNetworkTools(
            tempDirectory.path,
            enableDebugging: true,
            buildVendorTable: false,
          );

          Logger('configure_network_tools').fine('printed once');
          await Future<void>.delayed(const Duration(milliseconds: 50));
        },
        // The listener prints through the zone that installed it.
        zoneSpecification: ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, Object? line) =>
              printed.add(line.toString()),
        ),
      );

      expect(
        printed.where((line) => line.contains('printed once')),
        hasLength(1),
      );
    });

    test('stops the debug listener when debugging is turned off', () async {
      final printed = <String>[];

      await runZoned<Future<void>>(
        () async {
          await configureNetworkTools(
            tempDirectory.path,
            enableDebugging: true,
            buildVendorTable: false,
          );
          await configureNetworkTools(
            tempDirectory.path,
            buildVendorTable: false,
          );

          Logger('configure_network_tools').fine('not printed');
          await Future<void>.delayed(const Duration(milliseconds: 50));
        },
        // The listener prints through the zone that installed it.
        zoneSpecification: ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, Object? line) =>
              printed.add(line.toString()),
        ),
      );

      expect(printed.where((line) => line.contains('not printed')), isEmpty);
    });

    test('lets the isolate that scanned terminate', () async {
      final workDirectory = await Directory.systemTemp.createTemp(
        'network_tools_shutdown_',
      );
      final reportPort = ReceivePort();
      final exitPort = ReceivePort();
      final errorPort = ReceivePort();
      final errors = <Object?>[];
      errorPort.listen(errors.add);
      final exited = Completer<void>();
      exitPort.listen((dynamic _) {
        if (!exited.isCompleted) exited.complete();
      });

      final Isolate isolate = await Isolate.spawn(
        _configureScanAndClose,
        _ShutdownRequest(
          reportTo: reportPort.sendPort,
          dbPath: workDirectory.path,
        ),
        onExit: exitPort.sendPort,
        onError: errorPort.sendPort,
      );

      String report = 'no report';
      try {
        report =
            await reportPort.first.timeout(
                  const Duration(seconds: 30),
                  onTimeout: () => 'the scan never finished',
                )
                as String;
        await exited.future.timeout(
          const Duration(seconds: 20),
          onTimeout: () {},
        );
      } finally {
        isolate.kill();
        reportPort.close();
        exitPort.close();
        errorPort.close();
      }

      expect(errors, isEmpty, reason: 'the shutdown isolate failed: $errors');
      expect(report, 'SHUTDOWN-DONE');
      expect(
        exited.isCompleted,
        isTrue,
        reason: 'the isolate stayed alive, so shutdown leaked a resource',
      );

      await _deleteTempDirectory(workDirectory);
    });
  });
}
