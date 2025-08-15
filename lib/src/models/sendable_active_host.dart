import 'package:dart_ping/dart_ping.dart';

import 'package:network_tools/network_tools.dart';

class SendableActiveHost {
  SendableActiveHost(this.address, {this.pingData, this.openPorts = const []});
  final String address;
  final PingData? pingData;
  List<OpenPort> openPorts;
}
