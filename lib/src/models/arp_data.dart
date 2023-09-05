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
    if (Platform.isMacOS) {
      return '$host ($iPAddress) at $macAddress on $interfaceName ifscope [$interfaceType]';
    } else if (Platform.isLinux) {
      return '$host ($iPAddress) at $macAddress [$interfaceType] on $interfaceName';
    } else if (Platform.isWindows) {
      return 'Internet Address: $iPAddress, Physical Address: $macAddress, Type: $interfaceType';
    }
    return '$host ($iPAddress) at $macAddress on $interfaceName type [$interfaceType]';
  }
}
