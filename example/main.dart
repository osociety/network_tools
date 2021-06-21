import 'package:network_tools/network_tools.dart';

void main() {
  String ip = '192.168.1.12';
  // or You can also get ip using network_info_plus package
  // final String? ip = await (NetworkInfo().getWifiIP());
  final String subnet = ip.substring(0, ip.lastIndexOf('.'));
  final stream = HostScanner.discover(subnet, firstSubnet: 1, lastSubnet: 50,
      progressCallback: (progress) {
    print('Progress for host discovery : $progress');
  });

  stream.listen((host) {
    //Same host can be emitted multiple times
    //Use Set<ActiveHost> instead of List<ActiveHost>
    print('Found device: ${host}');
  }, onDone: () {
    print('Scan completed');
  }); // Don't forget to cancel the stream when not in use.

  String target = '192.168.1.1';
  PortScanner.discover(target, startPort: 0, endPort: 1024,
      progressCallback: (progress) {
    print('Progress for port discovery : $progress');
  }).listen((event) {
    if (event.isOpen) {
      print('Found open port : $event');
    }
  }, onDone: () {
    print('Scan completed');
  });
}
