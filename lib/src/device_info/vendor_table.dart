/// Provides utilities for normalizing MAC addresses for vendor lookup.
class VendorTable {
  /// Hex lengths of the IEEE assignment blocks, most specific first: MA-S and
  /// IAB (4.5 octets), MA-M (3.5 octets), then MA-L (3 octets).
  static const List<int> prefixLengths = [9, 7, 6];

  /// Normalizes a MAC address to upper-case hex with no separators.
  ///
  /// Accepts colon, dash and dot separated MACs as well as raw hex strings.
  static String normalizedHex(String macAddress) =>
      macAddress.replaceAll(RegExp('[^0-9a-fA-F]'), '').toUpperCase();

  /// Normalizes a MAC address to its upper-case, separator-free MA-L prefix.
  ///
  /// Returns the whole input when it is shorter than 3 octets. Use
  /// [normalizedHex] when the full address is needed, since MA-M, MA-S and IAB
  /// blocks are longer than 6 characters.
  static String noColonString(String macAddress) {
    final String hex = normalizedHex(macAddress);
    return hex.length > 6 ? hex.substring(0, 6) : hex;
  }
}
