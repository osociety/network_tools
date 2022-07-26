import 'package:dart_ping/dart_ping.dart';
import 'package:network_tools/src/models/mdns_info.dart';

/// ActiveHost which implements comparable
/// By default sort by hostId ascending
class ActiveHost extends Comparable<ActiveHost> {
  ActiveHost(
    this._ip,
    this._make,
    this._pingData, {
    this.mdnsInfo,
  }) {
    hostId = int.parse(_ip.substring(_ip.lastIndexOf('.') + 1, _ip.length));
  }

  static const generic = 'Generic Device';
  static const router = 'Router';
  final String _ip;
  late int hostId;
  final String _make;
  final PingData _pingData;
  MdnsInfo? mdnsInfo;

  String get ip => _ip;
  String get make => _make;
  PingData get pingData => _pingData;
  Duration? get responseTime => _pingData.response?.time;

  @override
  int get hashCode => _ip.hashCode;

  @override
  bool operator ==(dynamic o) => o is ActiveHost && _ip == o._ip;

  @override
  int compareTo(ActiveHost other) {
    return hostId.compareTo(other.hostId);
  }

  @override
  String toString() {
    return 'IP : $_ip, HostId : $hostId, make: $_make, Time: ${responseTime?.inMilliseconds}ms';
  }
}
