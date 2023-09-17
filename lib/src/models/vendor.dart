/// Gives vendor details matching as prefix of mac address
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

  final String macPrefix;
  final String vendorName;
  final String private;
  final String blockType;
  final String lastUpdate;
}
