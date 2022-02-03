import 'dart:async';
import 'dart:math';

import 'package:dart_ping/dart_ping.dart';
import 'package:network_tools/src/models/active_host.dart';
import 'package:network_tools/src/models/callbacks.dart';
import 'package:network_tools/src/models/open_port.dart';
import 'package:network_tools/src/port_scanner.dart';

/// Scans for all hosts in a subnet.
class HostScanner {
  /// Scans for all hosts in a particular subnet (e.g., 192.168.1.0/24)
  /// Set maxHost to higher value if you are not getting results.
  /// It won't firstSubnet again unless previous scan is completed due to heavy
  /// resource consumption.
  /// [resultsInIpAscendingOrder] = false will return results faster but not in
  /// ascending order and without [progressCallback].
  static Stream<ActiveHost> discover(
    String subnet, {
    int firstSubnet = 1,
    int lastSubnet = 254,
    int timeoutInSeconds = 1,
    ProgressCallback? progressCallback,
    bool resultsInIpAscendingOrder = true,
  }) async* {
    final int maxEnd = getMaxHost(subnet);
    if (firstSubnet > lastSubnet ||
        firstSubnet < 1 ||
        lastSubnet < 1 ||
        firstSubnet > maxEnd ||
        lastSubnet > maxEnd) {
      throw 'Invalid subnet range or firstSubnet < lastSubnet is not true';
    }
    final int lastValidSubnet = min(lastSubnet, maxEnd);

    final List<Future<ActiveHost?>> activeHostsFuture = [];
    final StreamController<ActiveHost> activeHostsController =
        StreamController<ActiveHost>();

    for (int i = firstSubnet; i <= lastValidSubnet; i++) {
      activeHostsFuture.add(
        _getHostFromPing(
          activeHostsController: activeHostsController,
          host: '$subnet.$i',
          i: i,
          timeoutInSeconds: timeoutInSeconds,
        ),
      );
    }

    if (!resultsInIpAscendingOrder) {
      yield* activeHostsController.stream;
    }

    int i = 0;
    for (final Future<ActiveHost?> host in activeHostsFuture) {
      i++;
      final ActiveHost? tempHost = await host;

      progressCallback
          ?.call((i - firstSubnet) * 100 / (lastValidSubnet - firstSubnet));

      if (tempHost == null) {
        continue;
      }
      yield tempHost;
    }
  }

  static Future<ActiveHost?> _getHostFromPing({
    required String host,
    required int i,
    required StreamController<ActiveHost> activeHostsController,
    int timeoutInSeconds = 1,
  }) async {
    await for (final PingData pingData
        in Ping(host, count: 1, timeout: timeoutInSeconds).stream) {
      final PingSummary? sum = pingData.summary;
      if (sum != null) {
        final int rec = sum.received;
        if (rec > 0) {
          final ActiveHost tempActiveHost =
              ActiveHost(host, i, ActiveHost.generic, pingData);
          activeHostsController.add(tempActiveHost);
          return tempActiveHost;
        }
      }
    }
    return null;
  }

  /// Scans for all hosts that have the specific port that was given.
  /// [resultsInIpAscendingOrder] = false will return results faster but not in
  /// ascending order and without [progressCallback].
  static Stream<OpenPort> discoverPort(
    String subnet,
    int port, {
    int firstSubnet = 1,
    int lastSubnet = 254,
    Duration timeout = const Duration(milliseconds: 2000),
    ProgressCallback? progressCallback,
    bool resultsInIpAscendingOrder = true,
  }) async* {
    final int maxEnd = getMaxHost(subnet);
    if (firstSubnet > lastSubnet ||
        firstSubnet < 1 ||
        lastSubnet < 1 ||
        firstSubnet > maxEnd ||
        lastSubnet > maxEnd) {
      throw 'Invalid subnet range or firstSubnet < lastSubnet is not true';
    }
    final int lastValidSubnet = min(lastSubnet, maxEnd);
    final List<Future<OpenPort>> openPortList = [];
    final StreamController<OpenPort> activeHostsController =
        StreamController<OpenPort>();

    for (int i = firstSubnet; i <= lastValidSubnet; i++) {
      final host = '$subnet.$i';
      openPortList.add(
        PortScanner.connectToPort(
          ip: host,
          port: port,
          timeout: timeout,
          activeHostsController: activeHostsController,
        ),
      );
    }

    if (!resultsInIpAscendingOrder) {
      yield* activeHostsController.stream;
    }

    int counter = firstSubnet;
    for (final Future<OpenPort> openPortFuture in openPortList) {
      yield await openPortFuture;
      progressCallback?.call(
        (counter - firstSubnet) * 100 / (lastValidSubnet - firstSubnet),
      );
      counter++;
    }
  }

  static int getMaxHost(String subnet) {
    final List<String> lastSubnetStr = subnet.split('.');
    if (lastSubnetStr.isEmpty) {
      throw 'Invalid subnet Address';
    }

    final int lastSubnet = int.parse(lastSubnetStr[0]);

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
