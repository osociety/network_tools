import 'package:network_tools/network_tools.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  int port = 0;
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
      }
    }
  });

  group('Testing Host Scanner', () {
    test('Running getAllPingableDevices tests', () {
      expectLater(
        //There should be at least one device pingable in network
        HostScanner.getAllPingableDevices(interfaceIp, timeoutInSeconds: 3),
        emits(isA<ActiveHost>()),
      );
      expectLater(
        //Should emit at least our own local machine when pinging all hosts.
        HostScanner.getAllPingableDevices(interfaceIp, timeoutInSeconds: 3),
        emitsThrough(ActiveHost(internetAddress: InternetAddress(myOwnHost))),
      );
    });

    test('Running getAllPingableDevicesAsync tests', () {
      expectLater(
        //There should be at least one device pingable in network
        HostScanner.getAllPingableDevicesAsync(
          interfaceIp,
          timeoutInSeconds: 3,
        ),
        emits(isA<ActiveHost>()),
      );
      expectLater(
        //Should emit at least our own local machine when pinging all hosts.
        HostScanner.getAllPingableDevicesAsync(
          interfaceIp,
          timeoutInSeconds: 3,
        ),
        emitsThrough(ActiveHost(internetAddress: InternetAddress(myOwnHost))),
      );
    });

    //todo: this test is not working on windows, not matter what.
    test('Running scanDevicesForSinglePort tests', () {
      expectLater(
        HostScanner.scanDevicesForSinglePort(
          interfaceIp, port, //ssh should be running at least in any host
        ), // hence some host will be emitted
        emits(isA<ActiveHost>()),
      );
    });

    test('Running getMaxHost tests', () {
      //Error thrown cases
      expect(() => HostScanner.getMaxHost(""), throwsArgumentError);
      expect(() => HostScanner.getMaxHost("x"), throwsFormatException);
      expect(() => HostScanner.getMaxHost("x.x.x"), throwsFormatException);
      expect(() => HostScanner.getMaxHost("256.0.0.0"), throwsRangeError);
      expect(
        () => HostScanner.getMaxHost(
          (HostScanner.minNetworkId - 1).toString(),
        ),
        throwsRangeError,
      );

      expect(
        () => HostScanner.getMaxHost(
          (HostScanner.maxNetworkId + 1).toString(),
        ),
        throwsRangeError,
      );

      //Normally returned cases
      expect(
        HostScanner.getMaxHost(HostScanner.minNetworkId.toString()),
        HostScanner.classASubnets,
      );
      expect(
        HostScanner.getMaxHost(HostScanner.maxNetworkId.toString()),
        HostScanner.classCSubnets,
      );
      expect(HostScanner.getMaxHost("10.0.0.0"), HostScanner.classASubnets);
      expect(HostScanner.getMaxHost("164.0.0.0"), HostScanner.classBSubnets);
      expect(HostScanner.getMaxHost("200.0.0.0"), HostScanner.classCSubnets);

      expect(
        ![HostScanner.classASubnets, HostScanner.classCSubnets]
            .contains(HostScanner.getMaxHost("164.0.0.0")),
        true,
      );
      expect(
        ![HostScanner.classBSubnets, HostScanner.classCSubnets]
            .contains(HostScanner.getMaxHost("10.0.0.0")),
        true,
      );
      expect(
        ![HostScanner.classASubnets, HostScanner.classBSubnets]
            .contains(HostScanner.getMaxHost("200.0.0.0")),
        true,
      );
    });
  });

  tearDownAll(() {
    server.close();
  });
}
