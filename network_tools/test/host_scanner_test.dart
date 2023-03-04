import 'package:network_tools/network_tools.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  group('Testing Host Scanner', () {
    String interfaceIp = "127.0.0";
    String myOwnHost = "127.0.0.1";
    //Fetching interface network
    setUp(() async {
      final interfaceList = await NetworkInterface.list();
      if (interfaceList.isNotEmpty) {
        final localInterface = interfaceList.elementAt(0);
        if (localInterface.addresses.isNotEmpty) {
          final address = localInterface.addresses.elementAt(0).address;
          myOwnHost = address;
          interfaceIp = address.substring(0, address.lastIndexOf('.'));
        }
      }
    });

    test('Running getAllPingableDevices tests', () {
      expectLater(
        HostScanner.getAllPingableDevices(interfaceIp),
        emits(isA<ActiveHost>()),
      );
      expectLater(
        HostScanner.getAllPingableDevices(interfaceIp),
        emitsThrough(ActiveHost(internetAddress: InternetAddress(myOwnHost))),
      );
    });

    test('Running scanDevicesForSinglePort tests', () {
      expectLater(
        HostScanner.scanDevicesForSinglePort(
          interfaceIp,
          22,
        ), //mysql should be running at least
        emits(isA<ActiveHost>()),
      );
    });

    test('Running getMaxHost tests', () {
      expect(HostScanner.getMaxHost("10.0.0.0"), HostScanner.classASubnets);
      expect(HostScanner.getMaxHost("164.0.0.0"), HostScanner.classBSubnets);
      expect(HostScanner.getMaxHost("200.0.0.0"), HostScanner.classCSubnets);
    });
  });
}
