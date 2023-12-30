/// Network tools base library
library network_tools;

import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:network_tools/injectable.dart';
import 'package:network_tools/src/device_info/vendor_table.dart';
import 'package:network_tools/src/network_tools_utils.dart';
import 'package:network_tools/src/services/arp_service.dart';

export 'src/device_info/net_interface.dart';
export 'src/device_info/vendor_table.dart';
export 'src/host_scanner.dart';
export 'src/mdns_scanner/list_of_srv_records.dart';
export 'src/mdns_scanner/mdns_scanner.dart';
export 'src/models/active_host.dart';
export 'src/models/arp_data.dart';
export 'src/models/callbacks.dart';
export 'src/models/mdns_info.dart';
export 'src/models/open_port.dart';
export 'src/models/sendable_active_host.dart';
export 'src/models/vendor.dart';
export 'src/port_scanner.dart';

final _getIt = GetIt.instance;
late bool _enableDebugging;

late String _dbDirectory;

String get dbDirectory => _dbDirectory;
bool get enableDebugging => _enableDebugging;

Future<void> configureNetworkTools(
  String dbDirectory, {
  bool enableDebugging = false,
}) async {
  _enableDebugging = enableDebugging;
  _dbDirectory = dbDirectory;
  if (enableDebugging) {
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
  configureDependencies();
  final arpService = await _getIt<ARPService>().open();
  await arpService.buildTable();
  await VendorTable.createVendorTableMap();
}
