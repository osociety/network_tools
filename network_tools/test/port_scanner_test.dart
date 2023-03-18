import 'dart:async';

import 'package:network_tools/network_tools.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  int port = 0; // keep this value between 1-2034
  final List<ActiveHost> hostsWithOpenPort = [];
  late ServerSocket server;
  // Fetching interfaceIp and hostIp
  setUpAll(() async {
    //open a port in shared way because of hostscanner using same,
    //if passed false then two hosts come up in search and breaks test.
    server =
        await ServerSocket.bind(InternetAddress.anyIPv4, port, shared: true);
    port = server.port;
    final interfaceList =
        await NetworkInterface.list(); //will give interface list
    if (interfaceList.isNotEmpty) {
      final localInterface =
          interfaceList.elementAt(0); //fetching first interface like en0/eth0
      if (localInterface.addresses.isNotEmpty) {
        final address = localInterface.addresses
            .elementAt(0)
            .address; //gives IP address of GHA local machine.
        final interfaceIp = address.substring(0, address.lastIndexOf('.'));
        //ssh should be running at least in any host
        await for (final host
            in HostScanner.scanDevicesForSinglePort(interfaceIp, port)) {
          hostsWithOpenPort.add(host);
        }
      }
    }
  });

  group('Testing Port Scanner', () {
    test('Running scanPortsForSingleDevice tests', () {
      for (final activeHost in hostsWithOpenPort) {
        final port = activeHost.openPorts.elementAt(0).port;
        expectLater(
          PortScanner.scanPortsForSingleDevice(
            activeHost.address,
            startPort: port - 1,
            endPort: port,
          ),
          emitsThrough(
            isA<ActiveHost>().having(
              (p0) => p0.openPorts.contains(OpenPort(port)),
              "Should match host having same open port",
              equals(true),
            ),
          ),
        );
      }
    });

    test('Running connectToPort tests', () {
      for (final activeHost in hostsWithOpenPort) {
        expectLater(
          PortScanner.connectToPort(
            address: activeHost.address,
            port: port,
            timeout: const Duration(seconds: 5),
            activeHostsController: StreamController<ActiveHost>(),
          ),
          completion(
            isA<ActiveHost>().having(
              (p0) => p0.openPorts.contains(OpenPort(port)),
              "Should match host having same open port",
              equals(true),
            ),
          ),
        );
      }
    });
    test('Running customDiscover tests', () {
      for (final activeHost in hostsWithOpenPort) {
        expectLater(
          PortScanner.customDiscover(activeHost.address, portList: [port]),
          emits(isA<ActiveHost>()),
        );
      }
    });

    test('Running customDiscover tests', () {
      for (final activeHost in hostsWithOpenPort) {
        expectLater(
          PortScanner.isOpen(activeHost.address, port),
          completion(
            isA<ActiveHost>().having(
              (p0) => p0.openPorts.contains(OpenPort(port)),
              "Should match host having same open port",
              equals(true),
            ),
          ),
        );
      }
    });
  });

  tearDownAll(() {
    server.close();
  });
}
