import 'package:json_annotation/json_annotation.dart';
import 'package:network_tools/src/database/drift_database.dart';
import 'package:universal_io/io.dart';

part 'arp_data.g.dart';

@JsonSerializable()
class ARPData {
  ARPData({
    required this.hostname,
    required this.iPAddress,
    required this.macAddress,
    required this.interfaceName,
    required this.interfaceType,
    required this.createdAt,
  });

  factory ARPData.fromJson(Map<String, dynamic> json) =>
      _$ARPDataFromJson(json);

  factory ARPData.fromDriftData(ARPDriftData arpData) => ARPData(
    hostname: arpData.hostname,
    iPAddress: arpData.iPAddress,
    macAddress: arpData.macAddress,
    interfaceName: arpData.interfaceName,
    interfaceType: arpData.interfaceType,
    createdAt: arpData.createdAt,
  );

  final String hostname;
  final String iPAddress;
  static const String primaryKeySembast = 'iPAddress';
  static const String nullIPAddress = '0.0.0.0';
  static const String nullMacAddress = 'ff:ff:ff:ff:ff:ff';
  static const String nullInterfaceType = 'ethernet';

  final String macAddress;
  final String interfaceName;
  final String interfaceType;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => _$ARPDataToJson(this);

  bool get notNullIPAddress => iPAddress != nullIPAddress;
  bool get notNullMacAddress => macAddress != nullMacAddress;
  bool get notNullInterfaceType => interfaceType != nullInterfaceType;

  @override
  String toString() {
    if (Platform.isMacOS) {
      return '$hostname ($iPAddress) at $macAddress on $interfaceName ifscope [$interfaceType]';
    } else if (Platform.isLinux) {
      return '$hostname ($iPAddress) at $macAddress [$interfaceType] on $interfaceName';
    } else if (Platform.isWindows) {
      return 'Internet Address: $iPAddress, Physical Address: $macAddress, Type: $interfaceType';
    }
    return '$hostname ($iPAddress) at $macAddress on $interfaceName type [$interfaceType]';
  }
}
