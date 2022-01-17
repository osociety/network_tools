/// Represents open port for a target IP
class OpenPort {
  OpenPort(this._ip, this._port, this._isOpen);

  final String _ip;
  final int _port;
  final bool _isOpen;

  String get ip => _ip;
  int get port => _port;
  bool get isOpen => _isOpen;
}
