import 'package:network_tools/network_tools.dart';

void main() {
  const String ip = '192.168.1.1';
  // or You can also get ip using network_info_plus package
  // final String? ip = await (NetworkInfo().getWifiIP());
  final String subnet = ip.substring(0, ip.lastIndexOf('.'));
  final stream = HostScanner.discover(
    subnet,
    firstSubnet: 1,
    lastSubnet: 254,
    progressCallback: (progress) {
      print('Progress for host discovery : $progress');
    },
  );

  stream.listen(
    (ActiveHost host) {
      //Same host can be emitted multiple times
      //Use Set<ActiveHost> instead of List<ActiveHost>
      print('Found device: $host');
    },
    onDone: () {
      print('Scan completed');
    },
  ); // Don't forget to cancel the stream when not in use.
}
