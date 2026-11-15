import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:network_tools/network_tools.dart' as packages_page;
import 'package:network_tools/src/database/drfit_database_service.dart';
import 'package:network_tools/src/database/drift_database.dart';
import 'package:network_tools/src/injection.dart';
import 'package:network_tools/src/models/arp_data.dart';
import 'package:network_tools/src/models/vendor.dart';
import 'package:network_tools/src/repository/repository.dart';
import 'package:network_tools/src/services/impls/host_scanner_service_impl.dart';
import 'package:network_tools/src/services/impls/mdns_scanner_service_impl.dart';
import 'package:network_tools/src/services/impls/port_scanner_service_impl.dart';

/// Handler installed by [configureNetworkTools] when debugging is enabled.
///
/// `Logger.root.onRecord` is a broadcast stream, so a listener that is never
/// removed prints every record again each time the package is configured.
StreamSubscription<LogRecord>? _debugLogSubscription;

/// Releases what [configureNetworkTools] opened and forgets it.
///
/// Without it the process outlives the app's work: the database connection owns
/// a background isolate that only terminates once the connection is closed.
/// Calling [configureNetworkTools] again afterwards works, so this is safe at the
/// end of a CLI or a test, not just before the app exits.
Future<void> closeNetworkTools() async {
  final AppDatabase? database = DriftDatabaseService.appDatabase;
  // The cache is dropped before the close is awaited so a scan that starts while
  // this is still running builds a fresh connection instead of writing to one
  // being torn down.
  DriftDatabaseService.reset();
  final StreamSubscription<LogRecord>? subscription = _debugLogSubscription;
  _debugLogSubscription = null;
  await subscription?.cancel();
  await database?.close();
}

/// Configures the network tools package for Dart native platforms.
///
/// Sets up the database directory, enables debugging if specified, and initializes
/// all required service implementations and vendor tables for network operations.
///
/// Call this once before using any scanner, usually from `main` after resolving
/// a writable [dbDirectory] such as the application documents directory.
/// [enableDebugging] forwards package logs to [Logger.root] at [Level.FINE];
/// [rebuildData] clears stale cached ARP entries before rebuilding the table.
///
/// [buildVendorTable] should stay `false` in worker isolates. Decoding the
/// vendor table costs a few milliseconds on first use, vendor lookups happen in
/// the isolate that created the host objects, and host discovery only needs the
/// ARP repository.
Future<void> configureNetworkTools(
  String dbDirectory, {
  bool enableDebugging = false,
  bool rebuildData = false,
  bool buildVendorTable = true,
}) async {
  final logger = Logger('configure_network_tools');
  packages_page.enableDebugging = enableDebugging;
  packages_page.dbDirectory = dbDirectory;

  final Directory newDirectory = Directory(packages_page.dbDirectory);
  await newDirectory.create(recursive: true);
  logger.fine('Directory created successfully: ${newDirectory.path}');

  if (packages_page.enableDebugging) {
    Logger.root.level = Level.FINE;
    await _debugLogSubscription?.cancel();
    _debugLogSubscription = Logger.root.onRecord.listen((record) {
      if (record.loggerName == logger.name) {
        // When debugging is enabled, log only the network_tools logger
        // ignore: avoid_print
        print(
          '${record.time.toLocal()}: ${record.level.name}: ${record.loggerName}: ${record.message}',
        );
      }
    });
  } else {
    // A reconfigure with debugging off must not leave the previous listener
    // printing.
    await _debugLogSubscription?.cancel();
    _debugLogSubscription = null;
  }

  // Setting dart native classes implementations
  HostScannerServiceImpl();
  PortScannerServiceImpl();
  MdnsScannerServiceImpl();

  await initializeNetworkTools(rebuildData, buildVendorTable: buildVendorTable);
}

/// Initializes the ARP table and vendor table map for network operations.
///
/// Prefer [configureNetworkTools], which also registers the service instances
/// and sets up logging. [buildVendorTable] is forwarded from there; pass
/// `false` in worker isolates so the vendor CSV is not downloaded there.
Future<void> initializeNetworkTools(
  bool rebuildData, {
  bool buildVendorTable = true,
}) async {
  // Configuring twice has to work: `closeNetworkTools` releases the database but
  // leaves the service locator alone, and the generated registrations throw when
  // a type is already there. Unregistering instead is not an option because this
  // is the app's own `GetIt.instance`, which holds its services too.
  if (!getIt.isRegistered<Repository<ARPData>>()) {
    configureDependencies(Env.prod);
  }
  if (rebuildData) {
    await getIt<Repository<ARPData>>().clear();
  }
  await getIt<Repository<ARPData>>().build();
  if (buildVendorTable) {
    await getIt<Repository<Vendor>>().build();
  }
}
