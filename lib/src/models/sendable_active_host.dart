import 'package:dart_ping/dart_ping.dart';

class SendableActiveHost {
  SendableActiveHost(this.address, this.pingData);
  final String address;
  final PingData pingData;
}
