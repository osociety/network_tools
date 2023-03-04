import 'dart:io';
import '../lib/network_tools.dart';

void main() {
  print("Run host scan : 'dart example/host_scan.dart'");
  print("Run port scan : 'dart example/port_scan.dart'");
  print("Run mdns scan : 'dart example/mdns_scan.dart'");
  _findLocal();
}

_findLocal() async {
  String interfaceIp = "127.0.0";
  String myOwnHost = "127.0.0.1";
  final interfaceList = await NetworkInterface.list();
  if (interfaceList.isNotEmpty) {
    final localInterface = interfaceList.elementAt(0);
    if (localInterface.addresses.isNotEmpty) {
      final address = localInterface.addresses.elementAt(0).address;
      myOwnHost = address;
      print(address);
      interfaceIp = address.substring(0, address.lastIndexOf('.'));
    }
  }

  HostScanner().getAllPingableDevices(interfaceIp).listen((event) {
    print(event);
  });
}
