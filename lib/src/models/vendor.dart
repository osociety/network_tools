import 'package:json_annotation/json_annotation.dart';
import 'package:network_tools/src/database/drift_database.dart';
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

  factory Vendor.fromCSVField(List<String> csvField) {
    String fieldAt(int index) =>
        index < csvField.length ? csvField[index].trim() : '';
    return Vendor(
      macPrefix: csvField[0]
          .replaceAll(RegExp('[^0-9a-fA-F]'), '')
          .toUpperCase(),
      vendorName: fieldAt(1),
      private: fieldAt(2),
      blockType: fieldAt(3),
      lastUpdate: fieldAt(4),
    );
  }
  factory Vendor.fromJson(Map<String, dynamic> json) => _$VendorFromJson(json);
  factory Vendor.fromDriftData(VendorDriftData data) {
    return Vendor(
      macPrefix: data.macPrefix,
      vendorName: data.vendorName,
      private: data.private,
      blockType: data.blockType,
      lastUpdate: data.lastUpdate,
    );
  }

  Map<String, dynamic> toJson() => _$VendorToJson(this);

  final String macPrefix;
  final String vendorName;
  final String private;
  final String blockType;
  final String lastUpdate;
}
