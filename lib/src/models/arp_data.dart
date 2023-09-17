import 'dart:io';
import 'package:json_annotation/json_annotation.dart';

part 'arp_data.g.dart';

@JsonSerializable()
class ARPData {
  ARPData({
    required this.host,
    required this.iPAddress,
    required this.macAddress,
    required this.interfaceName,
    required this.interfaceType,
  });
  factory ARPData.fromJson(Map<String, dynamic> json) =>
      _$ARPDataFromJson(json);

  final String? host;
  final String? iPAddress;
  final String? macAddress;
  final String? interfaceName;
  final String? interfaceType;

  Map<String, dynamic> toJson() => _$ARPDataToJson(this);

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
