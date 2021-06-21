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
  ///It won't firstSubnet again unless previous scan is completed due to heavy resource consumption.
  static Stream<ActiveHost> discover(
    String subnet, {
    int firstSubnet = 1,
    int lastSubnet = 50,
    ProgressCallback? progressCallback,
  }) async* {
    int maxEnd = getMaxHost(subnet);
    if (firstSubnet > lastSubnet ||
        firstSubnet < 1 ||
        lastSubnet < 1 ||
        firstSubnet > maxEnd ||
        lastSubnet > maxEnd) {
      throw 'Invalid subnet range or firstSubnet < lastSubnet is not true';
    }
    lastSubnet = min(lastSubnet, maxEnd);
    if (_scanning) {
      print('Previous scan is not being completed');
      return;
    }
    _scanning = true;
    for (int i = firstSubnet; i <= lastSubnet; i++) {
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
      progressCallback
          ?.call((i - firstSubnet) * 100 / (lastSubnet - firstSubnet));
    }
    _scanning = false;
  }

  static int getMaxHost(String subnet) {
    List<String> lastSubnetStr = subnet.split('.');
    if (lastSubnetStr.isEmpty) {
      throw 'Invalid subnet Address';
    }

    int lastSubnet = int.parse(lastSubnetStr[0]);

    if (lastSubnet < 128) {
      return 16777216;
    } else if (lastSubnet >= 128 && lastSubnet < 192) {
      return 65536;
    } else if (lastSubnet >= 192 && lastSubnet < 224) {
      return 256;
    }
    return 256;
  }
}
