import 'package:logging/logging.dart';
import 'package:network_tools/network_tools.dart' as pacakges_page;
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
  pacakges_page.enableDebugging = enableDebugging;
  pacakges_page.dbDirectory = dbDirectory;

  if (pacakges_page.enableDebugging) {
    Logger.root.level = Level.FINE;
    Logger.root.onRecord.listen((record) {
      if (record.loggerName == log.name) {
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
  await pacakges_page.VendorTable.createVendorTableMap();
}
