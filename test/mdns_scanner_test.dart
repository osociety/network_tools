import 'dart:io';

import 'package:logging/logging.dart';
import 'package:network_tools/network_tools.dart';
import 'package:test/test.dart';

void main() {
  // Logger.root.level = Level.FINE;
  // Logger.root.onRecord.listen((record) {
  //   print(
  //     '${DateFormat.Hms().format(record.time)}: ${record.level.name}: ${record.loggerName}: ${record.message}',
  //   );
  // });
  final log = Logger("mdns_scan_test");
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
        log.fine(
          'Fetched own host as $myOwnHost and interface address as $interfaceIp',
        );
      }
    }
  });
  group("Running mdns scanner group", () {
    test('Running searchMdnsDevices tests', () async {
      final mdnsDevices = await MdnsScanner.searchMdnsDevices();
      expectLater(
        mdnsDevices,
        isA<List<ActiveHost>>(),
      );
      expectLater(
        mdnsDevices,
        contains(predicate<ActiveHost>((host) => host.address == myOwnHost)),
      );
    });
  });
}
