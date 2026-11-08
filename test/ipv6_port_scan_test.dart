import 'dart:io';

import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/services/impls/port_scanner_service_impl.dart';
import 'package:test/test.dart';

void main() {
  late List<ServerSocket> ipv6Servers;
  late List<int> openPorts;

  setUpAll(() async {
    PortScannerServiceImpl();
    ipv6Servers = <ServerSocket>[
      for (int i = 0; i < 3; i++)
        await ServerSocket.bind(InternetAddress.loopbackIPv6, 0),
    ];
    openPorts = ipv6Servers.map((ServerSocket s) => s.port).toList()..sort();
  });

  tearDownAll(() async {
    for (final ServerSocket server in ipv6Servers) {
      await server.close();
    }
  });

  group('IPv6 port scanning', () {
    test('isOpen finds an open port on IPv6 loopback', () async {
      final result = await PortScannerService.instance.isOpen(
        InternetAddress.loopbackIPv6.address,
        openPorts.first,
      );

      expect(result, isNotNull);
      expect(result!.openPorts.single.port, openPorts.first);
    });

    test('isOpen returns null for a closed port on IPv6 loopback', () async {
      final closedPort = await _unusedIPv6Port();

      final result = await PortScannerService.instance.isOpen(
        InternetAddress.loopbackIPv6.address,
        closedPort,
        timeout: const Duration(milliseconds: 300),
      );

      expect(result, isNull);
    });

    test('customDiscover emits every open port on IPv6 loopback', () async {
      final hosts = await PortScannerService.instance
          .customDiscover(
            InternetAddress.loopbackIPv6.address,
            portList: openPorts,
            maxConcurrency: 2,
          )
          .toList();

      expect(
        hosts.map((ActiveHost h) => h.openPorts.single.port).toSet(),
        openPorts.toSet(),
      );
    });

    test('customDiscover async mode works with IPv6 loopback', () async {
      final hosts = await PortScannerService.instance
          .customDiscover(
            InternetAddress.loopbackIPv6.address,
            portList: openPorts,
            async: true,
            maxConcurrency: 2,
          )
          .toList();

      expect(hosts, hasLength(openPorts.length));
    });

    test('scanPortsForSingleDevice finds open ports on IPv6 loopback',
        () async {
      final firstPort = openPorts.first;
      final hosts = await PortScannerService.instance
          .scanPortsForSingleDevice(
            InternetAddress.loopbackIPv6.address,
            startPort: firstPort,
            endPort: firstPort,
            maxConcurrency: 1,
          )
          .toList();

      expect(hosts, hasLength(1));
      expect(hosts.single.openPorts.single.port, firstPort);
    });
  });
}

Future<int> _unusedIPv6Port() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv6, 0);
  final port = socket.port;
  await socket.close();
  return port;
}
