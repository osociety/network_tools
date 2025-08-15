import 'package:dart_ping/dart_ping.dart';
import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/network_tools_utils.dart';
import 'package:network_tools/src/services/arp_service.dart';
import 'package:universal_io/io.dart';

/// ActiveHost which implements comparable
/// By default sort by hostId ascending
class ActiveHost {
  ActiveHost({
    required this.internetAddress,
    this.openPorts = const [],
    String? macAddress,
    PingData? pingData,
    MdnsInfo? mdnsInfoVar,
  }) {
    _macAddress = macAddress;
    final String tempAddress = internetAddress.address;

    if (tempAddress.contains('.')) {
      hostId = tempAddress.substring(
        tempAddress.lastIndexOf('.') + 1,
        tempAddress.length,
      );
    } else if (tempAddress.contains(':')) {
      hostId = tempAddress.substring(
        tempAddress.lastIndexOf(':') + 1,
        tempAddress.length,
      );
    } else {
      hostId = '-1';
    }
    pingData ??= getPingData(tempAddress);
    _pingData = pingData;

    hostName = setHostInfo();

    // For some reason when internetAddress.host get called before the reverse
    // there is weired value
    weirdHostName = internetAddress.host;

    if (mdnsInfoVar != null) {
      mdnsInfo = Future.value(mdnsInfoVar);
    } else {
      mdnsInfo = setMdnsInfo();
    }

    deviceName = setDeviceName();

    // fetch entry from in memory arp table
    arpData = setARPData();

    // fetch vendor from in memory vendor table
    vendor = setVendor();
  }
  factory ActiveHost.buildWithAddress({
    required String address,
    String? macAddress,
    List<OpenPort> openPorts = const [],
    PingData? pingData,
    MdnsInfo? mdnsInfo,
  }) {
    final InternetAddress? internetAddressTemp = InternetAddress.tryParse(
      address,
    );
    if (internetAddressTemp == null) {
      throw 'Cant parse address $address to InternetAddress';
    }
    return ActiveHost(
      internetAddress: internetAddressTemp,
      macAddress: macAddress,
      openPorts: openPorts,
      pingData: pingData,
      mdnsInfoVar: mdnsInfo,
    );
  }

  factory ActiveHost.fromSendableActiveHost({
    required SendableActiveHost sendableActiveHost,
    String? macAddress,
    MdnsInfo? mdnsInfo,
  }) {
    final InternetAddress? internetAddressTemp = InternetAddress.tryParse(
      sendableActiveHost.address,
    );
    if (internetAddressTemp == null) {
      throw 'Cant parse address ${sendableActiveHost.address} to InternetAddress';
    }
    return ActiveHost(
      internetAddress: internetAddressTemp,
      macAddress: macAddress,
      openPorts: sendableActiveHost.openPorts,
      pingData: sendableActiveHost.pingData,
      mdnsInfoVar: mdnsInfo,
    );
  }

  static const generic = 'Generic Device';

  InternetAddress internetAddress;

  /// The device specific number in the ip address. In IPv4 numbers after the
  /// last dot, in IPv6 the numbers after the last colon
  late String hostId;

  /// Host name of the device, not to be confused with deviceName which does
  /// not follow any internet protocol property
  late Future<String?> hostName;
  late String weirdHostName;
  late final PingData _pingData;

  /// Mdns information of this device
  late Future<MdnsInfo?> mdnsInfo;

  /// Resolve ARP data for this host.
  /// only supported on Linux, Macos and Windows otherwise null
  late Future<ARPData?> arpData;

  /// Only works if arpData is not null and have valid mac address.
  late Future<Vendor?> vendor;

  String? _macAddress;
  Future<String?> getMacAddress() async =>
      _macAddress ?? (await arpData)?.macAddress;

  /// List of all the open port of this device
  List<OpenPort> openPorts;

  /// This device name does not following any guideline and is just some name
  /// that we can show for the device.
  /// Preferably hostName, if not than mDNS name, if not than will get the
  /// value of [generic].
  /// This value **can change after the object got created** since getting
  /// host name of device is running async function.
  late Future<String> deviceName;
  PingData get pingData => _pingData;
  Duration? get responseTime => _pingData.response?.time;
  String get address => internetAddress.address;

  static PingData getPingData(String host) {
    const int timeoutInSeconds = 1;

    PingData tempPingData = const PingData();

    Ping(
      host,
      count: 1,
      timeout: timeoutInSeconds,
      forceCodepage: Platform.isWindows,
    ).stream.listen((pingData) {
      final PingResponse? response = pingData.response;
      if (response != null) {
        final Duration? time = response.time;
        if (time != null) {
          tempPingData = pingData;
        }
      }
    });
    return tempPingData;
  }

  /// Try to find the host name of this device, if not exist host name will
  /// stay null
  Future<String?> setHostInfo() async {
    // For some reason when internetAddress.host get called before the reverse
    // there is weired value
    weirdHostName = internetAddress.host;

    // In the future if mdnsInfo is null it will execute a search
    // Currently the functionality is missing in dart multicast_dns package
    // https://github.com/flutter/flutter/issues/96755

    try {
      internetAddress = await internetAddress.reverse();
      return internetAddress.host;
    } catch (e) {
      if (e is SocketException &&
          e.osError != null &&
          (e.osError!.message == 'Name or service not known')) {
        // Some devices does not have host name and the reverse search will just
        // throw exception.
        // We don't need to print this crash as it is by design.
      } else {
        logger.severe('Exception here: $e');
      }
    }
    return null;
  }

  Future<void> resolveInfo() async {
    await arpData;
    // await vendor;
    await deviceName;
    await mdnsInfo;
    await hostName;
  }

  Future<ARPData?> setARPData() async {
    await ARPService.instance.open();
    return ARPService.instance.entryFor(address);
  }

  Future<Vendor?> setVendor() async {
    final String? macAddress = await getMacAddress();

    return macAddress == null ? null : VendorTable.macToVendor(macAddress);
  }

  /// Try to find the mdns name of this device, if not exist mdns name will
  /// be null
  /// TODO: search mdns name for each device
  Future<MdnsInfo?> setMdnsInfo() async {
    return null;
  }

  /// Set some kind of device name.
  /// Will try couple of names, if all are null will just return [generic]
  Future<String> setDeviceName() async {
    final String? hostNameTemp = await hostName;

    if (hostNameTemp != null) {
      return hostNameTemp;
    }
    final MdnsInfo? mdnsTemp = await mdnsInfo;
    if (mdnsTemp != null) {
      return mdnsTemp.getOnlyTheStartOfMdnsName();
    }
    return generic;
  }

  @override
  int get hashCode => address.hashCode;

  @override
  bool operator ==(Object o) => o is ActiveHost && address == o.address;

  int compareTo(ActiveHost other) {
    return hostId.compareTo(other.hostId);
  }

  @override
  String toString() {
    return 'Address: $address, HostId: $hostId, Time: ${responseTime?.inMilliseconds}ms, port: ${openPorts.join(",")}';
  }

  Future<String> toStringFull() async {
    return 'Address: $address, MAC: ${(await arpData)?.macAddress}, HostId: $hostId, Vendor: ${(await vendor)?.vendorName} Time: ${responseTime?.inMilliseconds}ms, DeviceName: ${await deviceName}, HostName: ${await hostName}, MdnsInfo: ${await mdnsInfo}';
  }
}
