import 'package:universal_io/io.dart';

/// Represents a network interface with its network ID, host ID, and IP address.
class NetInterface {
  /// Creates a [NetInterface] with the given [networkId], [hostId], and [ipAddress].
  NetInterface({
    required this.networkId,
    required this.hostId,
    required this.ipAddress,
  });

  final String networkId;
  final int hostId;
  final String ipAddress;

  /// Returns the local network interface information for the first available IPv4 interface.
  ///
  /// This method fetches the list of network interfaces and returns a [NetInterface]
  /// object for the first interface found, or null if none are available.
  static Future<NetInterface?> localInterface() async {
    final interfaceList = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    ); //will give interface list
    if (interfaceList.isNotEmpty) {
      final localInterface =
          interfaceList.first; //fetching first interface like en0/eth0
      if (localInterface.addresses.isNotEmpty) {
        final address = localInterface.addresses
            .elementAt(0)
            .address; //gives IP address of GHA local machine.
        final networkId = address.substring(0, address.lastIndexOf('.'));
        final hostId = int.parse(
          address.substring(address.lastIndexOf('.') + 1, address.length),
        );
        return NetInterface(
          networkId: networkId,
          hostId: hostId,
          ipAddress: address,
        );
      }
    }
    return null;
  }
}
