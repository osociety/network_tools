import 'dart:async';
import 'dart:math';
import 'package:dart_ping/dart_ping.dart';
import 'models/active_host.dart';
import 'models/callbacks.dart';

///Scans for all hosts in a subnet.
class HostScanner {
  static bool _scanning = false;

  /// Return true if scan is in progress
  static bool get isScanning => _scanning;

  ///Scans for all hosts in a particular subnet (e.g., 192.168.1.0/24)
  ///Set maxHost to higher value if you are not getting results.
  ///It won't start again unless previous scan is completed due to heavy resource consumption.
  static Stream<ActiveHost> discover(
    String subnet, {
    int maxHost = 50,
    ProgressCallback? progressCallback,
  }) async* {
    maxHost = min(maxHost, _getMaxHost(_lastNetworkAddress(subnet)));
    if (_scanning) {
      print('Previous scan is not being completed');
      return;
    }
    _scanning = true;
    for (int i = 1; i < maxHost; i++) {
      final host = '$subnet.$i';
      final ping = Ping(host, count: 1, timeout: 1);

      await for (PingData pingData in ping.stream) {
        if (pingData.summary != null) {
          PingSummary? sum = pingData.summary;
          if (sum != null) {
            int rec = sum.received;
            if (rec > 0) {
              yield ActiveHost(host, i, ActiveHost.GENERIC);
            }
          }
          print(pingData);
        }
      }
      progressCallback?.call(i * 100 / maxHost);
    }
    _scanning = false;
  }

  static int _getMaxHost(int end) {
    if (end < 128) {
      return 16777216;
    } else if (end >= 128 && end < 192) {
      return 65536;
    } else if (end >= 192 && end < 224) {
      return 256;
    }
    return 256;
  }

  static int _lastNetworkAddress(String subnet) {
    List<String> end = subnet.split('.');
    if (end.isEmpty) {
      throw 'Invalid subnet Address';
    }
    return int.parse(end[0]);
  }
}
