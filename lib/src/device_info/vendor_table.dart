/// Provides utilities for normalizing MAC addresses for vendor lookup.
class VendorTable {
  /// Normalizes a MAC address to the upper-case, separator-free prefix that
  /// is stored in the vendor table.
  ///
  /// Accepts colon, dash and dot separated MACs as well as raw hex strings.
  static String noColonString(String macAddress) {
    final String hex = macAddress
        .replaceAll(RegExp('[^0-9a-fA-F]'), '')
        .toUpperCase();
    return hex.length > 6 ? hex.substring(0, 6) : hex;
  }
}
