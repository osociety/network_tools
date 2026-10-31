import 'dart:io';
import 'dart:isolate';

import 'package:drift/native.dart';
import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/database/drfit_database_service.dart';
import 'package:network_tools/src/database/drift_database.dart';
import 'package:network_tools/src/services/impls/host_scanner_service_impl.dart';
import 'package:network_tools/src/services/impls/port_scanner_service_impl.dart';
import 'package:test/test.dart';

/// Returns immediately, so the spawner's exit port reports the death.
void _exitImmediately(SendPort sendPort) {}

/// Dies with an uncaught error, so the spawner's error port reports it.
void _crashImmediately(SendPort sendPort) {
  throw StateError('simulated isolate crash');
}

void main() {
  late Directory tempDirectory;
  late AppDatabase database;

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp('nt_isolate_');
    // Keep the database in memory. A file-backed database lives in
    // [tempDirectory], and Windows refuses to delete a directory that still
    // holds the open SQLite file, failing tearDownAll with errno 32.
    database = AppDatabase(NativeDatabase.memory());
    DriftDatabaseService.appDatabase = database;
    await configureNetworkTools(tempDirectory.path, buildVendorTable: false);
  });

  tearDownAll(() async {
    await database.close();
    await tempDirectory.delete(recursive: true);
  });

  group('host scan isolate failures', () {
    test('surfaces an uncaught isolate error', () async {
      final service = HostScannerServiceImpl(
        spawnScanIsolate: (entryPoint, sendPort, errorPort, exitPort) =>
            Isolate.spawn(
              _crashImmediately,
              sendPort,
              onError: errorPort,
              onExit: exitPort,
            ),
      );

      await expectLater(
        service.getAllPingableDevicesAsync('127.0.0', hostIds: [1]).drain(),
        throwsA(isA<Exception>()),
      );
    });

    test('surfaces an isolate that exits before the scan finishes', () async {
      final service = HostScannerServiceImpl(
        spawnScanIsolate: (entryPoint, sendPort, errorPort, exitPort) =>
            Isolate.spawn(
              _exitImmediately,
              sendPort,
              onError: errorPort,
              onExit: exitPort,
            ),
      );

      await expectLater(
        service.getAllPingableDevicesAsync('127.0.0', hostIds: [1]).drain(),
        throwsA(isA<Exception>()),
      );
    });

    test('reports configuration failures raised inside the isolate', () async {
      // A directory below a regular file cannot be created, so the isolate
      // fails while configuring itself.
      final blocker = File('${tempDirectory.path}/blocker')
        ..writeAsStringSync('not a directory');
      final configuredDirectory = dbDirectory;
      dbDirectory = '${blocker.path}/nested';

      try {
        await expectLater(
          HostScannerServiceImpl()
              .getAllPingableDevicesAsync('127.0.0', hostIds: [1])
              .drain(),
          throwsA(isA<Exception>()),
        );
      } finally {
        dbDirectory = configuredDirectory;
      }
    });
  });

  group('port scan isolate failures', () {
    test('surfaces an uncaught isolate error', () async {
      final service = PortScannerServiceImpl(
        spawnScanIsolate: (entryPoint, sendPort, errorPort, exitPort) =>
            Isolate.spawn(
              _crashImmediately,
              sendPort,
              onError: errorPort,
              onExit: exitPort,
            ),
      );

      await expectLater(
        service.customDiscover('127.0.0.1', portList: [1], async: true).drain(),
        throwsA(isA<Exception>()),
      );
    });

    test('surfaces an isolate that exits before the scan finishes', () async {
      final service = PortScannerServiceImpl(
        spawnScanIsolate: (entryPoint, sendPort, errorPort, exitPort) =>
            Isolate.spawn(
              _exitImmediately,
              sendPort,
              onError: errorPort,
              onExit: exitPort,
            ),
      );

      await expectLater(
        service.customDiscover('127.0.0.1', portList: [1], async: true).drain(),
        throwsA(isA<Exception>()),
      );
    });
  });
}
