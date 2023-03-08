/// Represents open port for a target Address
class OpenPort extends Comparable<OpenPort> {
  OpenPort(this._port, {this.isOpen = true});

  final int _port;
  final bool isOpen;

  int get port => _port;

  @override
  int compareTo(OpenPort other) {
    return _port.compareTo(other.port);
  }

  @override
  int get hashCode => _port.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OpenPort && other.port == port;
  }

  @override
  String toString() {
    return _port.toString();
  }
}
