import 'dart:io';

import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/services/impls/host_scanner_service_impl.dart';
import 'package:network_tools/src/services/impls/port_scanner_service_impl.dart';
import 'package:test/test.dart';

void main() {
  late List<ServerSocket> servers;
  late List<int> openPorts;

  setUpAll(() async {
    HostScannerServiceImpl();
    PortScannerServiceImpl();
    servers = <ServerSocket>[
      for (int i = 0; i < 3; i++)
        await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
    ];
    openPorts = servers.map((ServerSocket server) => server.port).toList()
      ..sort();
  });

  tearDownAll(() async {
    for (final ServerSocket server in servers) {
      await server.close();
    }
  });

  group('customDiscover', () {
    test('emits every open port', () async {
      final hosts = await PortScannerService.instance
          .customDiscover(
            InternetAddress.loopbackIPv4.address,
            portList: openPorts,
            maxConcurrency: 2,
          )
          .toList();

      expect(
        hosts.map((ActiveHost host) => host.openPorts.single.port).toSet(),
        openPorts.toSet(),
      );
    });

    test('keeps portList order in ordered mode', () async {
      final hosts = await PortScannerService.instance
          .customDiscover(
            InternetAddress.loopbackIPv4.address,
            portList: openPorts,
          )
          .toList();

      expect(
        hosts.map((ActiveHost host) => host.openPorts.single.port).toList(),
        openPorts,
      );
    });

    test('unordered mode still closes the stream', () async {
      final hosts = await PortScannerService.instance
          .customDiscover(
            InternetAddress.loopbackIPv4.address,
            portList: openPorts,
            resultsInAddressAscendingOrder: false,
            maxConcurrency: 1,
          )
          .toList();

      expect(hosts, hasLength(openPorts.length));
    });

    test('skips invalid ports', () async {
      final hosts = await PortScannerService.instance
          .customDiscover(
            InternetAddress.loopbackIPv4.address,
            portList: <int>[-1, 70000, openPorts.first],
          )
          .toList();

      expect(hosts, hasLength(1));
      expect(hosts.single.openPorts.single.port, openPorts.first);
    });

    test('async mode forwards progress from the isolate', () async {
      final progress = <double>[];
      final hosts = await PortScannerService.instance
          .customDiscover(
            InternetAddress.loopbackIPv4.address,
            portList: openPorts,
            async: true,
            progressCallback: progress.add,
          )
          .toList();

      expect(hosts, hasLength(openPorts.length));
      expect(progress, isNotEmpty);
    });
  });

  group('scanDevicesForSinglePort', () {
    test('finds the host with the open port', () async {
      final hosts = await HostScannerService.instance
          .scanDevicesForSinglePort('127.0.0', openPorts.first, lastHostId: 1)
          .toList();

      expect(hosts, hasLength(1));
      expect(hosts.single.address, InternetAddress.loopbackIPv4.address);
      expect(hosts.single.openPorts.single.port, openPorts.first);
    });

    test('unordered mode still closes the stream', () async {
      final hosts = await HostScannerService.instance
          .scanDevicesForSinglePort(
            '127.0.0',
            openPorts.first,
            lastHostId: 1,
            resultsInAddressAscendingOrder: false,
          )
          .toList();

      expect(hosts, hasLength(1));
    });

    test('hides hosts that do not have the port open', () async {
      final closedPort = await _unusedPort();

      final hosts = await HostScannerService.instance
          .scanDevicesForSinglePort(
            '127.0.0',
            closedPort,
            lastHostId: 1,
            timeout: const Duration(milliseconds: 300),
          )
          .toList();

      expect(hosts, isEmpty);
    });
  });
}

Future<int> _unusedPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}
