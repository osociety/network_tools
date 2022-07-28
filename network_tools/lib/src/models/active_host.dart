import 'package:dart_ping/dart_ping.dart';
import 'package:network_tools/src/models/mdns_info.dart';
import 'package:network_tools/src/models/open_port.dart';
import 'package:universal_io/io.dart';

/// ActiveHost which implements comparable
/// By default sort by hostId ascending
class ActiveHost extends Comparable<ActiveHost> {
  ActiveHost({
    required this.internetAddress,
    this.openPort = const [],
    PingData? pingData,
    this.mdnsInfo,
  }) {
    final String _ip = internetAddress.address;

    if (_ip.contains('.')) {
      hostId = _ip.substring(_ip.lastIndexOf('.') + 1, _ip.length);
    } else if (_ip.contains(':')) {
      hostId = _ip.substring(_ip.lastIndexOf(':') + 1, _ip.length);
    } else {
      hostId = '-1';
    }

    pingData ??= getPingData(_ip);
    _pingData = pingData;
    waitingForActiveHostSetupToComplete = setHostNameAndMdns();
  }

  factory ActiveHost.buildWithIp({
    required String ip,
    List<OpenPort> openPort = const [],
    PingData? pingData,
    MdnsInfo? mdnsInfo,
  }) {
    final InternetAddress? internetAddressTemp = InternetAddress.tryParse(ip);
    if (internetAddressTemp == null) {
      throw 'Cant parse ip $ip to InternetAddress';
    }
    return ActiveHost(
      internetAddress: internetAddressTemp,
      openPort: openPort,
      pingData: pingData,
      mdnsInfo: mdnsInfo,
    );
  }

  static const generic = 'Generic Device';
  InternetAddress internetAddress;
  late String hostId;
  String? hostName;
  String? weirdHostName;
  late final PingData _pingData;

  /// Mdns information of this device
  MdnsInfo? mdnsInfo;

  /// List of all the open port of this device
  List<OpenPort> openPort;

  /// This device name does not following any guideline and is just some name
  /// that we can show for the device.
  /// Preferably hostName, if not than mDNS name, if not than will get the
  /// value of [generic].
  /// This value **can change after the object got created** since getting
  /// host name of device is running async function.
  String deviceName = generic;
  PingData get pingData => _pingData;
  Duration? get responseTime => _pingData.response?.time;
  String get ip => internetAddress.address;

  /// This var let us know from out side if all the setup got completed.
  /// Since getting host name is async function [ActiveHost] does not contain
  /// all of the values when the constructor completed
  late Future<void> waitingForActiveHostSetupToComplete;

  @override
  int get hashCode => internetAddress.address.hashCode;

  @override
  bool operator ==(dynamic o) =>
      o is ActiveHost && internetAddress.address == o.internetAddress.address;

  @override
  int compareTo(ActiveHost other) {
    return hostId.compareTo(other.hostId);
  }

  @override
  String toString() {
    return 'IP: ${internetAddress.address}, HostId: $hostId, deviceName: $deviceName, Time: ${responseTime?.inMilliseconds}ms';
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
  Future<void> setHostNameAndMdns() async {
    // For some reason when internetAddress.host get called before the reverse
    // there is weired value
    weirdHostName = internetAddress.host;

    // In the future if mdnsInfo is null it will execute a search
    // Currently the functionality is missing in dart multicast_dns package
    // https://github.com/flutter/flutter/issues/96755

    try {
      internetAddress = await internetAddress.reverse();
      hostName = internetAddress.host;
      deviceName = hostName!;
    } catch (e) {
      // Some devices does not have host name and the reverse search will just
      // throw exception.
      if (mdnsInfo != null) {
        deviceName = mdnsInfo!.getOnlyTheStartOfMdnsName();
      }
    }
  }
}
