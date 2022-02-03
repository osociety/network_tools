import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:network_tools/network_tools.dart';

void main() {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((record) {
    print(
        '${DateFormat.Hms().format(record.time)}: ${record.level.name}: ${record.loggerName}: ${record.message}');
  });

  final _log = Logger('host_scan');
  const String ip = '192.168.1.1';
  // or You can also get ip using network_info_plus package
  // final String? ip = await (NetworkInfo().getWifiIP());
  final String subnet = ip.substring(0, ip.lastIndexOf('.'));
  final stream = HostScanner.discover(
    subnet,
    firstSubnet: 1,
    lastSubnet: 254,
    progressCallback: (progress) {
      _log.finer('Progress for host discovery : $progress');
    },
  );

  stream.listen(
    (ActiveHost host) {
      //Same host can be emitted multiple times
      //Use Set<ActiveHost> instead of List<ActiveHost>
      _log.fine('Found device: $host');
    },
    onDone: () {
      _log.fine('Scan completed');
    },
  ); // Don't forget to cancel the stream when not in use.
}
