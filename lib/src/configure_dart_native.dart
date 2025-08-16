import 'dart:io';

import 'package:logging/logging.dart';
import 'package:network_tools/network_tools.dart' as packages_page;
import 'package:network_tools/src/injection.dart';
import 'package:network_tools/src/models/arp_data.dart';
import 'package:network_tools/src/models/vendor.dart';
import 'package:network_tools/src/services/impls/host_scanner_service_impl.dart';
import 'package:network_tools/src/services/impls/mdns_scanner_service_impl.dart';
import 'package:network_tools/src/services/impls/port_scanner_service_impl.dart';
import 'package:network_tools/src/services/repository.dart';

/// Configures the network tools package for Dart native platforms.
///
/// Sets up the database directory, enables debugging if specified, and initializes
/// all required service implementations and vendor tables for network operations.
Future<void> configureNetworkTools(
  String dbDirectory, {
  bool enableDebugging = false,
  bool rebuildData = false,
}) async {
  final logger = Logger('configure_network_tools');
  packages_page.enableDebugging = enableDebugging;
  packages_page.dbDirectory = dbDirectory;

  final Directory newDirectory = Directory(packages_page.dbDirectory);
  await newDirectory.create(recursive: true);
  logger.fine('Directory created successfully: ${newDirectory.path}');

  if (packages_page.enableDebugging) {
    Logger.root.level = Level.FINE;
    Logger.root.onRecord.listen((record) {
      if (record.loggerName == logger.name) {
        // When debugging is enabled, log only the network_tools logger
        // ignore: avoid_print
        print(
          '${record.time.toLocal()}: ${record.level.name}: ${record.loggerName}: ${record.message}',
        );
      }
    });
  }

  configureDependencies(Env.prod);
  // Setting dart native classes implementations
  HostScannerServiceImpl();
  PortScannerServiceImpl();
  MdnsScannerServiceImpl();

  if (rebuildData) {
    await getIt<Repository<ARPData>>().clear();
  }
  await getIt<Repository<ARPData>>().build();
  await getIt<Repository<Vendor>>().build();
}
