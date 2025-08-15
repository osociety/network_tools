import 'dart:io';

import 'package:logging/logging.dart';
import 'package:network_tools/network_tools.dart' as packages_page;
import 'package:network_tools/src/services/arp_service.dart';
import 'package:network_tools/src/services/impls/arp_service_drift_impl.dart';
import 'package:network_tools/src/services/impls/host_scanner_service_impl.dart';
import 'package:network_tools/src/services/impls/mdns_scanner_service_impl.dart';
import 'package:network_tools/src/services/impls/port_scanner_service_impl.dart';

Future<void> configureNetworkTools(
  String dbDirectory, {
  bool enableDebugging = false,
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

  // Setting dart native classes implementations

  ARPServiceDriftImpl();
  HostScannerServiceImpl();
  PortScannerServiceImpl();
  MdnsScannerServiceImpl();

  final arpService = await ARPService.instance.open();
  await arpService.buildTable();
  await packages_page.VendorTable.createVendorTableMap();
}
