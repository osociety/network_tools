import 'dart:async';
import 'dart:math';

import 'package:dart_ping/dart_ping.dart';
import 'package:network_tools/network_tools.dart';

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
    bool showPingData = false,
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

    List<Future<ActiveHost?>> activeHostsFuture = [];

    for (int i = firstSubnet; i <= lastSubnet; i++) {
      final host = '$subnet.$i';
      final ping = Ping(host, count: 1, timeout: 1);

      HostScanner hostScanner = HostScanner();
      activeHostsFuture.add(
        hostScanner.getHostFromPing(
          host: host,
          i: i,
          pingStream: ping.stream,
          showPingData: showPingData,
        ),
      );
    }

    int i = 0;
    for (Future<ActiveHost?> host in activeHostsFuture) {
      i++;
      ActiveHost? tempHost = await host;

      progressCallback
          ?.call((i - firstSubnet) * 100 / (lastSubnet - firstSubnet));

      if (tempHost == null) {
        continue;
      }
      yield tempHost;
    }

    _scanning = false;
  }

  Future<ActiveHost?> getHostFromPing({
    required String host,
    required int i,
    required Stream<PingData> pingStream,
    bool showPingData = false,
  }) async {
    await for (PingData pingData in pingStream) {
      if (pingData.summary != null) {
        PingSummary? sum = pingData.summary;
        if (sum != null) {
          int rec = sum.received;
          if (rec > 0) {
            return ActiveHost(host, i, ActiveHost.GENERIC);
          }
        }
        if (showPingData) {
          print(pingData);
        }
      }
    }
    return null;
  }

  static Stream<OpenPort> discoverPort(
    String subnet,
    int port, {
    int firstSubnet = 1,
    int lastSubnet = 50,
    Duration timeout = const Duration(milliseconds: 500),
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
    for (int i = firstSubnet; i <= lastSubnet; i++) {
      final host = '$subnet.$i';
      yield await PortScanner.connectToPort(host, port, timeout);
      progressCallback
          ?.call((i - firstSubnet) * 100 / (lastSubnet - firstSubnet));
    }
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
