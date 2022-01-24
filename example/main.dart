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
    (host) {
      //Same host can be emitted multiple times
      //Use Set<ActiveHost> instead of List<ActiveHost>
      print('Found device: $host');
    },
    onDone: () {
      print('Scan completed');
    },
  ); // Don't forget to cancel the stream when not in use.

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
    endPort: 65535,
    progressCallback: (progress) {
      print('Progress for port discovery : $progress');
    },
  ).listen(
    (event) {
      if (event.isOpen) {
        print('Found open port : $event');
      }
    },
    onDone: () {
      print('Port Scan from 0 to 65535 completed');
    },
  );
}
