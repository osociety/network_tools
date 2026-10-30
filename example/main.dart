// ignore_for_file: avoid_print

import 'package:network_tools/network_tools.dart';

/// Discovers every device on the local network and prints its details.
///
/// Run it from the package root with:
///
/// ```sh
/// dart run example/main.dart
/// ```
///
/// More focused examples live in `example/lib/scan/`:
/// - `host_scan.dart` for ARP-first host discovery
/// - `port_scan.dart` for open port scans
/// - `mdns_scan.dart` for mDNS discovery
Future<void> main() async {
  // Prepares the database used for ARP and MAC vendor lookups.
  await configureNetworkTools('build');

  final interface = await NetInterface.localInterface();
  final String subnet = interface?.networkId ?? '192.168.1';
  print('Scanning $subnet.0/24 ...');

  final Stream<ActiveHost> hosts = HostScannerService.instance
      .getAllPingableDevices(
        subnet,
        timeoutInSeconds: 1,
        progressCallback: (double progress) {
          print('Progress: ${progress.toStringAsFixed(0)}%');
        },
      );

  await for (final ActiveHost host in hosts) {
    // Host details are resolved lazily, so discovery is not delayed by them.
    final String deviceName = await host.deviceName;
    final String? macAddress = await host.getMacAddress();
    final Vendor? vendor = await host.vendor;

    print(
      '${host.address.padRight(15)} $deviceName'
      '${macAddress == null ? '' : ' [$macAddress]'}'
      '${vendor == null ? '' : ' ${vendor.vendorName}'}',
    );
  }

  print('Scan completed.');
}
