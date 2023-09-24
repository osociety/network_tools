/// Network tools base library
library network_tools;

import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:network_tools/injectable.dart';
import 'package:network_tools/src/device_info/vendor_table.dart';
import 'package:network_tools/src/services/arp_service.dart';

export 'src/device_info/net_interface.dart';
export 'src/device_info/vendor_table.dart';
export 'src/host_scanner.dart';
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
final _arpServiceFuture = _getIt<ARPService>().open();

Future<void> configureNetworkTools({
  bool enableDebugging = false,
}) async {
  if (enableDebugging) {
    Logger.root.level = Level.FINE;
    Logger.root.onRecord.listen((record) {
      // ignore: avoid_print
      print(
        '${record.time.toLocal()}: ${record.level.name}: ${record.loggerName}: ${record.message}',
      );
    });
  }
  configureDependencies();

  await (await _arpServiceFuture).buildTable();
  await VendorTable.createVendorTableMap();
}
