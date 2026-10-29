# Cross Platform Network Tools

[![pub package](https://img.shields.io/pub/v/network_tools.svg)](https://pub.dev/packages/network_tools) [![Dart](https://github.com/osociety/network_tools/actions/workflows/dart.yml/badge.svg)](https://github.com/osociety/network_tools/actions/workflows/dart.yml) [![Code Coverage](https://github.com/osociety/network_tools/actions/workflows/static.yml/badge.svg)](https://osociety.github.io/network_tools) [![codecov](https://codecov.io/gh/osociety/network_tools/graph/badge.svg?token=J9G2472GQZ)](https://codecov.io/gh/osociety/network_tools)

Network Tools Supported

1. Host Scanner
   1. Search all devices on subnet
   2. Get hostname, MAC address and vendor of devices on Linux, macOS and Windows.
   3. Search devices for a specific port open.
   4. Isolate based scanning for large subnets.

2. Port Scanner
   1. Single Port scan
   2. Range
   3. Custom
   4. Bounded concurrency to scan fast without exhausting file descriptors.

Partly Work:

1. Mdns Scanner

## Network Tools Flutter package

Please check [network_tools_flutter](https://github.com/osociety/network_tools_flutter) package for extensive support to features on different platforms.

## Import package in your app 

```dart
import 'package:network_tools/network_tools.dart';

```

## Configure network tools in main function

### For dart native

```dart
Future<void> main() async {
  await configureNetworkTools('build', enableDebugging: true);
  runApp(const MyApp());
}
```

### For flutter apps

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // It's necessary to pass correct path to be able to use this library.
  final appDocDirectory = await getApplicationDocumentsDirectory();
  await configureNetworkTools(appDocDirectory.path, enableDebugging: true);
  runApp(const MyApp());
}
```

Pass `buildVendorTable: false` from worker isolate entry points. The vendor
table downloads a multi-megabyte CSV on first use, and vendor lookups happen in
the isolate that receives the hosts, not the one that starts the scan. Scans
started through `getAllPingableDevicesAsync` already do this.

## Usage

### Host Scanner

```dart
 String address = '192.168.1.12';
  // or You can also get address using network_info_plus package
  // final String? address = await (NetworkInfo().getWifiIP());
  final String subnet = address.substring(0, address.lastIndexOf('.'));
  final stream = HostScannerService.instance.getAllPingableDevices(subnet, firstHostId: 1, lastHostId: 50,
      progressCallback: (progress) {
    print('Progress for host discovery : $progress');
  });

  stream.listen((host) {
    //Same host can be emitted multiple times
    //Use Set<ActiveHost> instead of List<ActiveHost>
    print('Found device: $host');
  }, onDone: () {
    print('Scan completed');
  }); // Don't forget to cancel the stream when not in use.
```

Host details (hostname, MAC address and vendor) are resolved lazily on first
access, so discovery is not slowed down by additional lookups:

```dart
  await for (final ActiveHost host in HostScannerService.instance.getAllPingableDevices(subnet)) {
    final String deviceName = await host.deviceName;
    final String? macAddress = await host.getMacAddress();
    final Vendor? vendor = await host.vendor;
    print('${host.address} $deviceName $macAddress ${vendor?.vendorName}');
  }
```

For large subnets use `getAllPingableDevicesAsync`, which runs the whole scan in
a separate isolate so the UI stays responsive:

```dart
  await for (final ActiveHost host
      in HostScannerService.instance.getAllPingableDevicesAsync('192.168.1')) {
    print('Found device: ${host.address}');
  }
```

#### How discovery works

On Linux, macOS and Windows a scan primes the neighbour cache by sending a UDP
datagram to every address in the range, then reads the numeric ARP table once
(`arp -an` on macOS, `/proc/net/arp` on Linux, `arp -a` on Windows). This
replaces one `ping` process per address, so a /24 scan typically finishes in
about a second and still reports hosts that ignore ICMP. Broadcast and
multicast MAC rows are discarded. Mobile platforms and non-local subnets fall
back to the ICMP sweep.

ARP itself carries no host names, so `hostName` and `deviceName` are resolved
separately for the hosts that were actually found: a concurrent reverse DNS
lookup with a short budget during the scan, and a fresh attempt when the name is
first accessed. Networks without reverse DNS (most home routers) simply return
no name; `deviceName` then falls back to mDNS, then the ARP table entry, then
`Generic Device`. MAC vendor lookups still work on those networks.

On Android and iOS names depend on platform multicast and local-network
permissions:

- **Android**: hold a `MulticastLock` (`CHANGE_WIFI_MULTICAST_STATE`) for mDNS,
  and request `ACCESS_FINE_LOCATION` for Wi-Fi details.
- **iOS**: enable the multicast networking entitlement and request local
  network permission (`NSLocalNetworkUsageDescription`).

### Port Scanner

```dart
  //1. Range
  String target = '192.168.1.1';
  PortScannerService.instance.scanPortsForSingleDevice(target, startPort: 1, endPort: 1024,
      progressCallback: (progress) {
    print('Progress for port discovery : $progress');
  }).listen((ActiveHost event) {
    if (event.openPorts.isNotEmpty) {
      print('Found open ports : ${event.openPorts}');
    }
  }, onDone: () {
    print('Scan completed');
  });
  //2. Single
  final bool isOpen = (await PortScannerService.instance.isOpen(target, 80)) != null;
  //3. Custom
  PortScannerService.instance.customDiscover(target, portList: const [22, 80, 139]);
```

Scans open at most `maxConcurrency` sockets at once (128 by default), so large
ranges complete quickly without hitting file-descriptor limits. Raise it for
more throughput or lower it to be gentler on the network. Pass `async: true` to
run the scan in an isolate.

Results are streamed as each port resolves, so you can show open ports before
the scan ends. In the default ordered mode a later result waits until every
earlier port has resolved; pass `resultsInAddressAscendingOrder: false` when
you want the earliest possible delivery and do not need a stable order.
`maxConcurrency` also controls how soon results for later ports can appear on
high-latency or filtered networks:

```dart
  await for (final ActiveHost host in PortScannerService.instance.scanPortsForSingleDevice(
    target,
    startPort: 1,
    endPort: 65535,
    maxConcurrency: 512,
    async: true,
  )) {
    print('Open ports on ${host.address}: ${host.openPorts}');
  }
```

### Mdns Scanner

```dart
  for (final ActiveHost activeHost in await MdnsScannerService.instance.searchMdnsDevices()) {
    final MdnsInfo? mdnsInfo = await activeHost.mdnsInfo;
    print('''
    Address: ${activeHost.address}
    Port: ${mdnsInfo!.mdnsPort}
    ServiceType: ${mdnsInfo.mdnsServiceType}
    MdnsName: ${mdnsInfo.getOnlyTheStartOfMdnsName()}
    ''');
  }
```

### Run examples

1. Run all examples : `dart run example/main.dart`
2. Run host scan : `dart run example/lib/scan/host_scan.dart`
3. Run port scan : `dart run example/lib/scan/port_scan.dart`
4. Run mdns scan : `dart run example/lib/scan/mdns_scan.dart`


## Sample App

[Vernet](https://github.com/osociety/vernet) is the open source cross platform
network analysis and monitoring app built on top of this library.
You can check out the code and implementation for more detailed use case of this package.

## Support and Donate

1. Support this project by becoming a stargazer of this project.
2. Donate via Liberapay: [liberapay.com/OpenSociety/donate](https://liberapay.com/OpenSociety/donate)
3. Support Open Society on Ko-fi:

   [![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/op3nsoc13ty)

Inspired from [ping_discover_network](https://github.com/andrey-ushakov/ping_discover_network)
