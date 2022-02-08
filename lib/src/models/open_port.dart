/// Represents open port for a target IP
class OpenPort {
  OpenPort(this._ip, this._port, {this.isOpen = false});

  final String _ip;
  final int _port;
  final bool isOpen;

  String get ip => _ip;
  int get port => _port;
}
