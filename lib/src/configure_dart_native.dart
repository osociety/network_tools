import 'package:logging/logging.dart';
import 'package:network_tools/network_tools.dart' as packages_page;
import 'package:network_tools/src/network_tools_utils.dart';
import 'package:network_tools/src/services/arp_service.dart';
import 'package:network_tools/src/services/impls/arp_service_sembast_impl.dart';
import 'package:network_tools/src/services/impls/host_scanner_service_impl.dart';
import 'package:network_tools/src/services/impls/mdns_scanner_service_impl.dart';
import 'package:network_tools/src/services/impls/port_scanner_service_impl.dart';

Future<void> configureNetworkTools(
  String dbDirectory, {
  bool enableDebugging = false,
}) async {
  packages_page.enableDebugging = enableDebugging;
  packages_page.dbDirectory = dbDirectory;

  if (packages_page.enableDebugging) {
    Logger.root.level = Level.FINE;
    Logger.root.onRecord.listen((record) {
      if (record.loggerName == logger.name) {
        // ignore: avoid_print
        print(
          '${record.time.toLocal()}: ${record.level.name}: ${record.loggerName}: ${record.message}',
        );
      }
    });
  }

  /// Setting dart native classes implementations
  ARPServiceSembastImpl();
  HostScannerServiceImpl();
  PortScannerServiceImpl();
  MdnsScannerServiceImpl();

  final arpService = await ARPService.instance.open();
  await arpService.buildTable();
  await packages_page.VendorTable.createVendorTableMap();
}
