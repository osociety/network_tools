import 'package:dart_ping/dart_ping.dart';
import 'package:network_tools/src/models/mdns_info.dart';
import 'package:network_tools/src/models/open_port.dart';
import 'package:network_tools/src/network_tools_utils.dart';
import 'package:universal_io/io.dart';

/// ActiveHost which implements comparable
/// By default sort by hostId ascending
class ActiveHost extends Comparable<ActiveHost> {
  ActiveHost({
    required this.internetAddress,
    // ignore: deprecated_consistency
    this.openPort = const [],
    PingData? pingData,
    MdnsInfo? mdnsInfoVar,
  }) {
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
  }

  factory ActiveHost.buildWithAddress({
    required String address,
    List<OpenPort> openPort = const [],
    PingData? pingData,
    MdnsInfo? mdnsInfo,
  }) {
    final InternetAddress? internetAddressTemp =
        InternetAddress.tryParse(address);
    if (internetAddressTemp == null) {
      throw 'Cant parse address $address to InternetAddress';
    }
    return ActiveHost(
      internetAddress: internetAddressTemp,
      openPort: openPort,
      pingData: pingData,
      mdnsInfoVar: mdnsInfo,
    );
  }

  static const generic = 'Generic Device';
  InternetAddress internetAddress;
  late String hostId;

  /// Host name of the device, not to be confused with deviceName which does
  /// not follow any internet protocol property
  late Future<String?> hostName;
  late String weirdHostName;
  late final PingData _pingData;

  /// Mdns information of this device
  late Future<MdnsInfo?> mdnsInfo;

  /// List of all the open port of this device
  @Deprecated("Grammar is wrong for variable, please use [openPorts]")
  List<OpenPort> openPort;

  List<OpenPort> get openPorts => openPort;

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

  @override
  int get hashCode => address.hashCode;

  @override
  bool operator ==(Object o) => o is ActiveHost && address == o.address;

  @override
  int compareTo(ActiveHost other) {
    return hostId.compareTo(other.hostId);
  }

  @override
  String toString() {
    return 'Address: $address, HostId: $hostId, Time: ${responseTime?.inMilliseconds}ms, port: ${openPorts.join(",")}';
  }

  Future<String> toStringFull() async {
    return 'Address: $address, HostId: $hostId Time: ${responseTime?.inMilliseconds}ms, DeviceName: ${await deviceName}, HostName: ${await hostName}, MdnsInfo: ${await mdnsInfo}';
  }

  static PingData getPingData(String host) {
    const int timeoutInSeconds = 1;

    PingData tempPingData = const PingData();

    Ping(host, count: 1, timeout: timeoutInSeconds).stream.listen((pingData) {
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
          e.osError!.message == 'Name or service not known') {
        // Some devices does not have host name and the reverse search will just
        // throw exception.
        // We don't need to print this crash as it is by design.
      } else {
        log.severe('Exception here: $e');
      }
    }
    return null;
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
}
