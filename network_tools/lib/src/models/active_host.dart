import 'package:dart_ping/dart_ping.dart';
import 'package:network_tools/src/models/mdns_info.dart';
import 'package:network_tools/src/models/open_port.dart';

/// ActiveHost which implements comparable
/// By default sort by hostId ascending
class ActiveHost extends Comparable<ActiveHost> {
  ActiveHost(
    this._ip, {
    this.openPort = const [],
    PingData? pingData,
    this.deviceName = generic,
    this.mdnsInfo,
  }) {
    hostId = int.parse(_ip.substring(_ip.lastIndexOf('.') + 1, _ip.length));
    pingData ??= getPingData(_ip);
    _pingData = pingData;
  }

  static const generic = 'Generic Device';
  static const router = 'Router';
  final String _ip;
  late int hostId;
  late final PingData _pingData;

  /// Mdns information of this device
  MdnsInfo? mdnsInfo;

  /// List of all the open port of this device
  List<OpenPort> openPort;

  String get ip => _ip;

  /// This device name does not following any guideline and is just some name
  /// that we find for the device
  final String deviceName;
  PingData get pingData => _pingData;
  Duration? get responseTime => _pingData.response?.time;

  @override
  int get hashCode => _ip.hashCode;

  @override
  bool operator ==(dynamic o) => o is ActiveHost && _ip == o._ip;

  @override
  int compareTo(ActiveHost other) {
    return hostId.compareTo(other.hostId);
  }

  @override
  String toString() {
    return 'IP : $_ip, HostId : $hostId, make: $deviceName, Time: ${responseTime?.inMilliseconds}ms';
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
