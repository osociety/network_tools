# Network Tools

[![pub package](https://img.shields.io/pub/v/network_tools.svg)](https://pub.dev/packages/network_tools) [![Dart](https://github.com/osociety/network_tools/actions/workflows/dart.yml/badge.svg)](https://github.com/osociety/network_tools/actions/workflows/dart.yml) [![codecov](https://codecov.io/gh/osociety/network_tools/graph/badge.svg?token=J9G2472GQZ)](https://codecov.io/gh/osociety/network_tools)

Network Tools Supported

1. Host Scanner
   1. Search all devices on subnet
   2. Get mac address of devices on Linux, macOS and Windows.
   3. Search devices for a specific port open.

2. Port Scanner
   1. Single Port scan
   2. Range
   3. Custom

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
  bool isOpen = (await PortScanner.isOpen(target, 80)) == null;
  //3. Custom
  PortScanner.customDiscover(target, portList: const [22, 80, 139]);
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

1. Run host scan : `dart example/host_scan.dart`
2. Run port scan : `dart example/port_scan.dart`
3. Run mdns scan : `dart example/mdns_scan.dart`


## Sample App

[Vernet](https://github.com/git-elliot/vernet) is the open source app built on top of this library.
You can check out the code and implementation for more detailed use case of this package.

## Support and Donate

1. Support this project by becoming stargazer of this project.
2. Buy me a coffee.

    | Librepay | 
    |----------|
    |<noscript><a href="https://liberapay.com/OpenSociety/donate"><img alt="Donate using Liberapay" src="https://liberapay.com/assets/widgets/donate.svg"></a></noscript>|

3. Support me on Ko-Fi

   [![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/fs0c13ty)

Inspired from [ping_discover_network](https://github.com/andrey-ushakov/ping_discover_network)
