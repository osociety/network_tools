///Represents open port for a target IP
class OpenPort {
  String _ip;
  int _port;
  bool _isOpen;
  OpenPort(this._ip, this._port, this._isOpen);
  String get ip => _ip;
  int get port => _port;
  bool get isOpen => _isOpen;
}
