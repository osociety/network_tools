import 'package:network_tools/network_tools.dart';

void main() {
  const String ip = '192.168.1.1';
  // or You can also get ip using network_info_plus package
  // final String? ip = await (NetworkInfo().getWifiIP());
  final String subnet = ip.substring(0, ip.lastIndexOf('.'));

  // [New] Scan for a single open port in a subnet
  final stream2 = HostScanner.discoverPort(
    subnet,
    53,
    firstSubnet: 1,
    lastSubnet: 254,
    progressCallback: (progress) {
      print('Progress for port discovery on host : $progress');
    },
  );

  stream2.listen(
    (port) {
      if (port.isOpen) {
        print('Found open port: ${port.port} on ${port.ip}');
      }
    },
    onDone: () {
      print('Port Scan completed');
    },
  ); // Don't forget to cancel the stream when not in use.

  const String target = '192.168.1.1';
  PortScanner.discover(
    target,
    startPort: 1,
    endPort: 9400,
    progressCallback: (progress) {
      print('Progress for port discovery : $progress');
    },
  ).listen(
    (event) {
      if (event.isOpen) {
        print('Found open port : ${event.port}');
      }
    },
    onDone: () {
      print('Port Scan from 1 to 9400 completed');
    },
  );
}
