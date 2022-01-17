/// ActiveHost which implements comparable
/// By default sort by hostId ascending
class ActiveHost extends Comparable<ActiveHost> {
  ActiveHost(this._ip, this.hostId, this._make);

  static const generic = 'Generic Device';
  static const router = 'Router';
  final String _ip;
  int hostId;
  final String _make;

  String get ip => _ip;
  String get make => _make;

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
    return 'IP : $_ip, HostId : $hostId, make: $_make';
  }
}
