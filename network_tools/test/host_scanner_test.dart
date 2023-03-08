import 'package:network_tools/network_tools.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

import 'network_tools_test.dart';

void main() {
  String interfaceIp = "127.0.0";
  String myOwnHost = "127.0.0.1";
  // Fetching interfaceIp and hostIp
  setUpAll(() async {
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
        HostScanner.getAllPingableDevices(interfaceIp),
        emits(isA<ActiveHost>()),
      );
      expectLater(
        //Should emit at least our own local machine when pinging all hosts.
        HostScanner.getAllPingableDevices(interfaceIp),
        emitsThrough(ActiveHost(internetAddress: InternetAddress(myOwnHost))),
      );
    });

    test('Running getAllPingableDevicesAsync tests', () {
      expectLater(
        //There should be at least one device pingable in network
        HostScanner.getAllPingableDevicesAsync(interfaceIp),
        emits(isA<ActiveHost>()),
      );
      expectLater(
        //Should emit at least our own local machine when pinging all hosts.
        HostScanner.getAllPingableDevicesAsync(interfaceIp),
        emitsThrough(ActiveHost(internetAddress: InternetAddress(myOwnHost))),
      );
    });

    test('Running scanDevicesForSinglePort tests', () {
      expectLater(
        HostScanner.scanDevicesForSinglePort(
          interfaceIp,
          port, //ssh should be running at least in any host
        ), // hence some host will be emitted
        emits(isA<ActiveHost>()),
      );
    });

    test('Running getMaxHost tests', () {
      expect(() => HostScanner.getMaxHost(""), throwsArgumentError);
      expect(() => HostScanner.getMaxHost("x"), throwsFormatException);
      expect(() => HostScanner.getMaxHost("x.x.x"), throwsFormatException);
      expect(() => HostScanner.getMaxHost("0"), throwsRangeError);
      expect(() => HostScanner.getMaxHost("0.0.0.0"), throwsRangeError);
      expect(() => HostScanner.getMaxHost("256.0.0.0"), throwsRangeError);

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
}
