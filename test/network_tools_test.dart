import 'dart:async';

import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/network_tools_utils.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  int port = 0;
  int hostId = 0;
  int firstHostId = 0;
  int lastHostId = 0;
  String myOwnHost = "0.0.0.0";
  final List<ActiveHost> hostsWithOpenPort = [];
  OpenPort? openPort;

  String interfaceIp = myOwnHost.substring(0, myOwnHost.lastIndexOf('.'));
  late ServerSocket server;
  // Fetching interfaceIp and hostIp
  setUpAll(() async {
    await configureNetworkTools('build', enableDebugging: true);
    //open a port in shared way because of portscanner using same,
    //if passed false then two hosts come up in search and breaks test.
    server = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );
    port = server.port;
    logger.fine("Opened port in this machine at $port");

    final interface = await NetInterface.localInterface();
    if (interface != null) {
      hostId = interface.hostId;
      interfaceIp = interface.networkId;
      myOwnHost = interface.ipAddress;
      // Better to restrict to scan from hostId - 1 to hostId + 1 to prevent GHA timeouts
      firstHostId = hostId <= 1 ? hostId : hostId - 1;
      lastHostId = hostId >= 254 ? hostId : hostId + 1;
      await for (final host
          in HostScannerService.instance.scanDevicesForSinglePort(
            interfaceIp,
            port,
          )) {
        hostsWithOpenPort.add(host);
        for (final tempOpenPort in host.openPorts) {
          if (tempOpenPort.port == port) {
            openPort = tempOpenPort;
            break;
          }
        }
      }
      logger.fine(
        'Fetched own host as $myOwnHost and interface address as $interfaceIp',
      );
    }
  });

  group('Model Coverage', () {
    test('Running OpenPort tests', () {
      final actualOpenPort = openPort;
      final expectedOpenPort = OpenPort(port);
      final json = <String, dynamic>{
        'port': expectedOpenPort.port,
        'isOpen': expectedOpenPort.isOpen,
      };

      if (actualOpenPort != null) {
        expect(actualOpenPort, expectedOpenPort);
        expect(actualOpenPort.compareTo(expectedOpenPort), 0);
      }
      expect(expectedOpenPort.isOpen, equals(true)); // because default is true
      expect(expectedOpenPort.hashCode, expectedOpenPort.port.hashCode);
      expect(expectedOpenPort.toString(), expectedOpenPort.port.toString());
      expect(expectedOpenPort.toJson(), json);
      expect(OpenPort.fromJson(json), expectedOpenPort);
    });
    test('Running ARPData tests', () {
      final json = <String, dynamic>{
        'hostname': 'Local',
        'iPAddress': '192.168.1.1',
        'macAddress': '00:00:3F:C1:DD:3E',
        'interfaceName': 'eth0',
        'interfaceType': 'bridge',
      };

      final arpData = ARPData.fromJson(json);
      expect(arpData.toJson(), json);
      expect(arpData.notNullIPAddress, true);
      expect(arpData.notNullMacAddress, true);
      expect(arpData.notNullInterfaceType, true);
    });

    test('Running Vendor tests', () {
      final json = <String, dynamic>{
        'macPrefix': '00:00:0C',
        'vendorName': 'Cisco Systems, Inc',
        'private': 'false',
        'blockType': 'MA-L',
        'lastUpdate': '2015/11/17',
      };
      final vendor = Vendor.fromJson(json);
      expect(vendor.toJson(), json);
    });
  });

  group('Testing Host Scanner group', () {
    test('Running getAllPingableDevices tests', () {
      expectLater(
        //There should be at least one device pingable in network
        HostScannerService.instance.getAllPingableDevices(
          interfaceIp,
          timeoutInSeconds: 3,
          firstHostId: firstHostId,
          lastHostId: lastHostId,
        ),
        emits(isA<ActiveHost>()),
      );
      expectLater(
        //There should be at least one device pingable in network when limiting to own hostId
        HostScannerService.instance.getAllPingableDevices(
          interfaceIp,
          timeoutInSeconds: 3,
          hostIds: [hostId],
          firstHostId: firstHostId,
          lastHostId: lastHostId,
        ),
        emits(isA<ActiveHost>()),
      );
      expectLater(
        //There should be at least one device pingable in network when limiting to hostId other than own
        HostScannerService.instance.getAllPingableDevices(
          interfaceIp,
          timeoutInSeconds: 3,
          hostIds: [0],
          firstHostId: firstHostId,
          lastHostId: lastHostId,
        ),
        neverEmits(isA<ActiveHost>()),
      );
      expectLater(
        //Should emit at least our own local machine when pinging all hosts.
        HostScannerService.instance.getAllPingableDevices(
          interfaceIp,
          timeoutInSeconds: 3,
          firstHostId: firstHostId,
          lastHostId: lastHostId,
        ),
        emitsThrough(ActiveHost(internetAddress: InternetAddress(myOwnHost))),
      );
    });

    test('Running getAllPingableDevicesAsync tests', () {
      expectLater(
        //There should be at least one device pingable in network
        HostScannerService.instance.getAllPingableDevicesAsync(
          interfaceIp,
          timeoutInSeconds: 3,
          firstHostId: firstHostId,
          lastHostId: lastHostId,
        ),
        emits(isA<ActiveHost>()),
      );
      expectLater(
        //Should emit at least our own local machine when pinging all hosts.
        HostScannerService.instance.getAllPingableDevicesAsync(
          interfaceIp,
          timeoutInSeconds: 3,
          firstHostId: firstHostId,
          lastHostId: lastHostId,
        ),
        emitsThrough(ActiveHost(internetAddress: InternetAddress(myOwnHost))),
      );
      expectLater(
        //There should be at least one device pingable in network when limiting to own hostId
        HostScannerService.instance.getAllPingableDevicesAsync(
          interfaceIp,
          timeoutInSeconds: 3,
          hostIds: [hostId],
          firstHostId: firstHostId,
          lastHostId: lastHostId,
        ),
        emits(isA<ActiveHost>()),
      );
      expectLater(
        //There should be at least one device pingable in network when limiting to hostId other than own
        HostScannerService.instance.getAllPingableDevicesAsync(
          interfaceIp,
          timeoutInSeconds: 3,
          hostIds: [0],
          firstHostId: firstHostId,
          lastHostId: lastHostId,
        ),
        neverEmits(isA<ActiveHost>()),
      );
    });

    test('Running scanDevicesForSinglePort tests', () {
      expectLater(
        HostScannerService.instance.scanDevicesForSinglePort(
          interfaceIp,
          port,
          firstHostId: firstHostId,
          lastHostId: lastHostId,
        ), // hence some host will be emitted
        emits(isA<ActiveHost>()),
      );
    });
  });

  group('Testing Port Scanner group', () {
    test('Running scanPortsForSingleDevice tests', () {
      for (final activeHost in hostsWithOpenPort) {
        final port = activeHost.openPorts.elementAt(0).port;
        expectLater(
          PortScannerService.instance.scanPortsForSingleDevice(
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

    test('Running scanPortsForSingleDevice Async tests', () {
      for (final activeHost in hostsWithOpenPort) {
        final port = activeHost.openPorts.elementAt(0).port;
        expectLater(
          PortScannerService.instance.scanPortsForSingleDevice(
            activeHost.address,
            startPort: port - 1,
            endPort: port,
            async: true,
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

    test('Running customDiscover tests', () {
      for (final activeHost in hostsWithOpenPort) {
        expectLater(
          PortScannerService.instance.customDiscover(
            activeHost.address,
            portList: [port],
          ),
          emits(isA<ActiveHost>()),
        );
      }
    });

    test('Running customDiscover Async tests', () {
      for (final activeHost in hostsWithOpenPort) {
        expectLater(
          PortScannerService.instance.customDiscover(
            activeHost.address,
            portList: [port],
            async: true,
          ),
          emits(isA<ActiveHost>()),
        );
      }
    });

    test('Running connectToPort tests', () {
      for (final activeHost in hostsWithOpenPort) {
        expectLater(
          PortScannerService.instance.connectToPort(
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

    test('Running isOpen tests', () {
      for (final activeHost in hostsWithOpenPort) {
        expectLater(
          PortScannerService.instance.isOpen(activeHost.address, port),
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

  group("Testing mdns scanner group", () {
    test('Running searchMdnsDevices tests', () async {
      final mdnsDevices = await MdnsScannerService.instance.searchMdnsDevices();
      expectLater(mdnsDevices, isA<List<ActiveHost>>());
      //todo: mdnsDevices are empty in GHA, open one to be discoverable
      // expectLater(
      //   mdnsDevices,
      //   contains(predicate<ActiveHost>((host) => host.address == myOwnHost)),
      // );
    });
  });

  tearDownAll(() {
    server.close();
  });
}
