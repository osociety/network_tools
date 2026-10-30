import 'package:json_annotation/json_annotation.dart';
import 'package:network_tools/src/database/drift_database.dart';
import 'package:universal_io/io.dart';

part 'arp_data.g.dart';

/// One row of the operating system's neighbor (ARP) table.
///
/// Host scanners attach these to [ActiveHost.arpData] on Linux, macOS and
/// Windows. The table is read in numeric form, so [hostname] is usually empty;
/// device names come from reverse DNS and mDNS instead.
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

  factory ARPData.fromRegExpMatch(RegExpMatch match) {
    final String parsedHostname = match.groupNames.contains('host')
        ? (match.namedGroup("host")?.trim() ?? nullHostName)
        : nullHostName;
    return ARPData(
      // `arp -an` prints "?" when it did not resolve a name; treat that as
      // "unknown" instead of a usable device name.
      hostname: parsedHostname == '?' ? nullHostName : parsedHostname,
      iPAddress: match.namedGroup("ip")?.trim() ?? ARPData.nullIPAddress,
      macAddress: match.namedGroup("mac")?.trim() ?? ARPData.nullMacAddress,
      interfaceName: match.groupNames.contains('intf')
          ? (match.namedGroup("intf")?.trim() ?? nullHostName)
          : nullHostName,
      interfaceType:
          match.namedGroup("typ")?.trim() ?? ARPData.nullInterfaceType,
      createdAt: DateTime.now(),
    );
  }

  /// Host name recorded in the table, or an empty string when the platform did
  /// not resolve one. Populated only by the name-resolving `arp -a` read.
  final String hostname;

  /// The host's IPv4 address.
  final String iPAddress;
  static const String primaryKeySembast = 'iPAddress';
  static const String nullIPAddress = '0.0.0.0';
  static const String nullMacAddress = 'ff:ff:ff:ff:ff:ff';
  static const String nullInterfaceType = 'ethernet';
  static const String nullHostName = '';

  /// MAC address of the host, normalized to two hex digits per octet.
  final String macAddress;

  /// Name of the interface the entry was learned on, e.g. `en0` or `eth0`.
  final String interfaceName;

  /// Link type reported by the platform, e.g. `ether` or `ethernet`.
  final String interfaceType;

  /// When this row was read into the local database.
  final DateTime createdAt;

  Map<String, dynamic> toJson() => _$ARPDataToJson(this);

  /// Whether [iPAddress] holds a real address instead of [nullIPAddress].
  bool get notNullIPAddress => iPAddress != nullIPAddress;

  /// Whether [macAddress] holds a real MAC instead of [nullMacAddress].
  bool get notNullMacAddress => macAddress != nullMacAddress;

  /// Whether [interfaceType] holds a real link type instead of
  /// [nullInterfaceType].
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
