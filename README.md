# Network Tools

[![pub package](https://img.shields.io/pub/v/network_tools.svg)](https://pub.dev/packages/network_tools) [![Dart](https://github.com/osociety/network_tools/actions/workflows/dart.yml/badge.svg)](https://github.com/osociety/network_tools/actions/workflows/dart.yml) [![codecov](https://codecov.io/gh/git-elliot/network_tools/branch/main/graph/badge.svg?token=J9G2472GQZ)](https://codecov.io/gh/git-elliot/network_tools)

Network Tools Supported

1. Host Scanner

2. Port Scanner
   1. Single
   2. Range
   3. Custom

Partly Work:

1. Mdns Scanner

## Import package in your app

```dart
import 'package:network_tools/network_tools.dart';
```

## Usage

### Host Scanner

```dart
 String address = '192.168.1.12';
  // or You can also get address using network_info_plus package
  // final String? address = await (NetworkInfo().getWifiIP());
  final String subnet = address.substring(0, address.lastIndexOf('.'));
  final stream = HostScanner.getAllPingableDevices(subnet, firstHostId: 1, lastHostId: 50,
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
  PortScanner.scanPortsForSingleDevice(target, startPort: 1, endPort: 1024,
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
  for (final ActiveHost activeHost in await MdnsScanner.searchMdnsDevices()) {
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

## Enable Debugging

Add this code to your `main.dart` file

```dart
    Logger.root.level = Level.FINE; //set to finest for detailed log
      Logger.root.onRecord.listen((record) {
        print(
            '${DateFormat.Hms().format(record.time)}: ${record.level.name}: ${record.loggerName}: ${record.message}');
      });
```

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
