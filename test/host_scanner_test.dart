import 'package:logging/logging.dart';
import 'package:network_tools/network_tools.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  final log = Logger("host_scan_test");

  // Logger.root.level = Level.FINE;
  // Logger.root.onRecord.listen((record) {
  //   print(
  //     '${DateFormat.Hms().format(record.time)}: ${record.level.name}: ${record.loggerName}: ${record.message}',
  //   );
  // });

  int port = 0;
  int firstHostId = 0;
  int lastHostId = 0;
  String myOwnHost = "0.0.0.0";

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
        log.fine(
          'Fetched own host as $myOwnHost and interface address as $interfaceIp',
        );
      }
    }
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

    //todo: this test is not working on windows, not matter what.
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

  tearDownAll(() {
    server.close();
  });
}
