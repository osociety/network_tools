import 'package:json_annotation/json_annotation.dart';
part 'vendor.g.dart';

/// Gives vendor details matching as prefix of mac address
@JsonSerializable()
class Vendor {
  Vendor({
    required this.macPrefix,
    required this.vendorName,
    required this.private,
    required this.blockType,
    required this.lastUpdate,
  });

  factory Vendor.fromCSVField(List<dynamic> csvField) {
    return Vendor(
      macPrefix: csvField[0] as String,
      vendorName: csvField[1].toString(),
      private: csvField[2] as String,
      blockType: csvField[3] as String,
      lastUpdate: csvField[4] as String,
    );
  }
  factory Vendor.fromJson(Map<String, dynamic> json) => _$VendorFromJson(json);

  Map<String, dynamic> toJson() => _$VendorToJson(this);

  final String macPrefix;
  final String vendorName;
  final String private;
  final String blockType;
  final String lastUpdate;
}
