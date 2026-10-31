import 'package:json_annotation/json_annotation.dart';

part 'vendor.g.dart';

/// Gives vendor details matching as prefix of mac address.
@JsonSerializable()
class Vendor {
  Vendor({
    required this.macPrefix,
    required this.vendorName,
    required this.private,
    required this.blockType,
    required this.lastUpdate,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) => _$VendorFromJson(json);

  Map<String, dynamic> toJson() => _$VendorToJson(this);

  final String macPrefix;
  final String vendorName;
  final String private;
  final String blockType;
  final String lastUpdate;
}
