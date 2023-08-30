import 'package:dart_ping/dart_ping.dart';

class SendableActivateHost{
  SendableActivateHost(this.address, this.pingData);
  final String address;
  final PingData pingData;
}
