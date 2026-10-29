import 'package:dart_ping/dart_ping.dart';

import 'package:network_tools/network_tools.dart';

class SendableActiveHost {
  SendableActiveHost(
    this.address, {
    this.pingData,
    this.openPorts = const [],
    this.macAddress,
    this.hostName,
  });

  final String address;
  final PingResponse? pingData;
  List<OpenPort> openPorts;

  /// MAC address read from the neighbor table during discovery, when available.
  final String? macAddress;

  /// Host name resolved during discovery so consumers do not have to wait for
  /// another lookup.
  final String? hostName;
}
