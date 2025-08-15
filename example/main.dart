import 'package:network_tools/network_tools.dart';

void main() async {
  // Example: Scan for active hosts in the local subnet (e.g., 192.168.1)
  // Change subnet value as needed for your network.
  final subnet = '192.168.29';
  print('Scanning for active hosts in ' + subnet + '.0/24 ...');
  await configureNetworkTools('build', enableDebugging: true);

  await for (final host in HostScannerService.instance.getAllPingableDevices(
    subnet,
  )) {
    // ignore: avoid_print
    print('Found host: ' + host.internetAddress.address);
  }
  // For more examples, you can run the following commands:
  // ignore: avoid_print
  print("Run host scan : 'dart example/lib/scan/host_scan.dart'");
  // ignore: avoid_print
  print("Run port scan : 'dart example/lib/scan/port_scan.dart'");
  // ignore: avoid_print
  print("Run mdns scan : 'dart example/lib/scan/mdns_scan.dart'");
}
