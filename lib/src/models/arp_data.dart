import 'dart:io';

class ARPData {
  ARPData({
    required this.host,
    required this.iPAddress,
    required this.macAddress,
    required this.interfaceName,
    required this.interfaceType,
  });

  final String? host;
  final String? iPAddress;
  final String? macAddress;
  final String? interfaceName;
  final String? interfaceType;

  @override
  String toString() {
    //TODO: add platform specific format
    if (Platform.isMacOS) {
      return '$host ($iPAddress) at $macAddress on $interfaceName ifscope [$interfaceType]';
    }
    return '$host ($iPAddress) at $macAddress on $interfaceName ifscope [$interfaceType]';
  }
}
