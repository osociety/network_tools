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
    this.deviceName = generic,
    this.mdnsInfo,
  }) {
    final String _ip = internetAddress.address;
    if (_ip.contains('.')) {
      hostId = int.parse(_ip.substring(_ip.lastIndexOf('.') + 1, _ip.length));
    } else if (_ip.contains(':')) {
      hostId = int.parse(_ip.substring(_ip.lastIndexOf(':') + 1, _ip.length));
    } else {
      hostId = -1;
    }
    pingData ??= getPingData(_ip);
    _pingData = pingData;
  }

  factory ActiveHost.buildWithIp({
    required String ip,
    List<OpenPort> openPort = const [],
    PingData? pingData,
    String deviceName = generic,
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
      deviceName: deviceName,
      mdnsInfo: mdnsInfo,
    );
  }

  static const generic = 'Generic Device';
  static const router = 'Router';
  final InternetAddress internetAddress;
  late int hostId;
  late final PingData _pingData;

  /// Mdns information of this device
  MdnsInfo? mdnsInfo;

  /// List of all the open port of this device
  List<OpenPort> openPort;

  /// This device name does not following any guideline and is just some name
  /// that we find for the device
  final String deviceName;
  PingData get pingData => _pingData;
  Duration? get responseTime => _pingData.response?.time;
  String get ip => internetAddress.address;

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
    return 'IP : ${internetAddress.address}, HostId : $hostId, make: $deviceName, Time: ${responseTime?.inMilliseconds}ms';
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
}
