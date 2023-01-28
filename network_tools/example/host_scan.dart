import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:network_tools/network_tools.dart';

void main() {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((record) {
    print(
      '${DateFormat.Hms().format(record.time)}: ${record.level.name}: ${record.loggerName}: ${record.message}',
    );
  });

  const String address = '192.168.1.1';
  // or You can also get address using network_info_plus package
  // final String? address = await (NetworkInfo().getWifiIP());
  final String subnet = address.substring(0, address.lastIndexOf('.'));

  // You can set [firstHostId] and scan will start from this host in the network.
  // Similarly set [lastHostId] and scan will end at this host in the network.
  final stream = HostScanner.getAllPingableDevices(
    subnet,
    // firstHostId: 1,
    // lastHostId: 254,
    progressCallback: (progress) {
      log.finer('Progress for host discovery : $progress');
    },
  );

  stream.listen(
    (ActiveHost host) async {
      //Same host can be emitted multiple times
      //Use Set<ActiveHost> instead of List<ActiveHost>
      log.fine('Found device: ${await host.toStringFull()}');
    },
    onDone: () {
      log.fine('Scan completed');
    },
  ); // Don't forget to cancel the stream when not in use.
}
