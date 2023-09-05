import 'dart:async';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:network_tools/network_tools.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  final log = Logger("host_scan_test");

  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((record) {
    print(
      '${DateFormat.Hms().format(record.time)}: ${record.level.name}: ${record.loggerName}: ${record.message}',
    );
  });

  int port = 0;
  int firstHostId = 0;
  int lastHostId = 0;
  String myOwnHost = "0.0.0.0";
  final List<ActiveHost> hostsWithOpenPort = [];
  OpenPort? openPort;

  String interfaceIp = myOwnHost.substring(0, myOwnHost.lastIndexOf('.'));
  late ServerSocket server;
  // Fetching interfaceIp and hostIp
  setUpAll(() async {
    //open a port in shared way because of portscanner using same,
    //if passed false then two hosts come up in search and breaks test.
    server =
        await ServerSocket.bind(InternetAddress.anyIPv4, port, shared: true);
    port = server.port;
    log.fine("Opened port in this machine at $port");
    final interfaceList =
        await NetworkInterface.list(); //will give interface list
    if (interfaceList.isNotEmpty) {
      final localInterface =
          interfaceList.elementAt(0); //fetching first interface like en0/eth0
      if (localInterface.addresses.isNotEmpty) {
        final address = localInterface.addresses
            .elementAt(0)
            .address; //gives IP address of GHA local machine.
        myOwnHost = address;
        interfaceIp = address.substring(0, address.lastIndexOf('.'));
        final hostId = int.parse(
          address.substring(address.lastIndexOf('.') + 1, address.length),
        );
        // Better to restrict to scan from hostId - 1 to hostId + 1 to prevent GHA timeouts
        firstHostId = hostId <= 1 ? hostId : hostId - 1;
        lastHostId = hostId >= 254 ? hostId : hostId + 1;
        await for (final host
            in HostScanner.scanDevicesForSinglePort(interfaceIp, port)) {
          hostsWithOpenPort.add(host);
          for (final tempOpenPort in host.openPorts) {
            if (tempOpenPort.port == port) {
              openPort = tempOpenPort;
              break;
            }
          }
        }
        log.fine(
          'Fetched own host as $myOwnHost and interface address as $interfaceIp',
        );
      }
    }
  });

  group('Model Coverage', () {
    test('Running OpenPort tests', () {
      final actualOpenPort = openPort;
      final expectedOpenPort = OpenPort(port);

      if (actualOpenPort != null) {
        expect(actualOpenPort, expectedOpenPort);
        expect(actualOpenPort.compareTo(expectedOpenPort), 0);
      }
      expect(expectedOpenPort.isOpen, equals(true)); // because default is true
      expect(expectedOpenPort.hashCode, expectedOpenPort.port.hashCode);
      expect(expectedOpenPort.toString(), expectedOpenPort.port.toString());
    });
  });

  group('Testing Host Scanner', () {
    test(
      'Running getAllPingableDevices tests',
      () {
        expectLater(
          //There should be at least one device pingable in network
          HostScanner.getAllPingableDevices(
            interfaceIp,
            timeoutInSeconds: 3,
            firstHostId: firstHostId,
            lastHostId: lastHostId,
          ),
          emits(isA<ActiveHost>()),
        );
        expectLater(
          //Should emit at least our own local machine when pinging all hosts.
          HostScanner.getAllPingableDevices(
            interfaceIp,
            timeoutInSeconds: 3,
            firstHostId: firstHostId,
            lastHostId: lastHostId,
          ),
          emitsThrough(ActiveHost(internetAddress: InternetAddress(myOwnHost))),
        );
      },
    );

    test(
      'Running getAllPingableDevicesAsync tests',
      () {
        expectLater(
          //There should be at least one device pingable in network
          HostScanner.getAllPingableDevicesAsync(
            interfaceIp,
            timeoutInSeconds: 3,
            firstHostId: firstHostId,
            lastHostId: lastHostId,
          ),
          emits(isA<ActiveHost>()),
        );
        expectLater(
          //Should emit at least our own local machine when pinging all hosts.
          HostScanner.getAllPingableDevicesAsync(
            interfaceIp,
            timeoutInSeconds: 3,
            firstHostId: firstHostId,
            lastHostId: lastHostId,
          ),
          emitsThrough(ActiveHost(internetAddress: InternetAddress(myOwnHost))),
        );
      },
    );

    test(
      'Running scanDevicesForSinglePort tests',
      () {
        expectLater(
          HostScanner.scanDevicesForSinglePort(
            interfaceIp,
            port,
            firstHostId: firstHostId,
            lastHostId: lastHostId,
          ), // hence some host will be emitted
          emits(isA<ActiveHost>()),
        );
      },
    );
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

  group("Running mdns scanner group", () {
    test('Running searchMdnsDevices tests', () async {
      final mdnsDevices = await MdnsScanner.searchMdnsDevices();
      expectLater(
        mdnsDevices,
        isA<List<ActiveHost>>(),
      );
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
