import 'package:dart_ping/dart_ping.dart';

/// ActiveHost which implements comparable
/// By default sort by hostId ascending
class ActiveHost extends Comparable<ActiveHost> {
  static const GENERIC = 'Generic Device';
  static const ROUTER = 'Router';
  String _ip;
  int hostId;
  String _make;
  PingData _pingData;

  String get ip => _ip;
  String get make => _make;
  PingData get pingData => _pingData;
  ActiveHost(this._ip, this.hostId, this._make, this._pingData);

  @override
  int get hashCode => _ip.hashCode;
  bool operator ==(o) => o is ActiveHost && _ip == o._ip;

  @override
  int compareTo(ActiveHost other) {
    return this.hostId.compareTo(other.hostId);
  }

  @override
  String toString() {
    return 'IP : $_ip, HostId : $hostId, make: $_make';
  }
}
