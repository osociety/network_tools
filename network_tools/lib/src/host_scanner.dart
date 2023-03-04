import 'dart:async';
import 'dart:math';

import 'package:dart_ping/dart_ping.dart';
import 'package:isolate_manager/isolate_manager.dart';
import 'package:network_tools/src/models/active_host.dart';
import 'package:network_tools/src/models/callbacks.dart';
import 'package:network_tools/src/port_scanner.dart';
import 'netowrk_tools_utils.dart';

/// Scans for all hosts in a subnet.
class HostScanner {
  /// Scans for all hosts in a particular subnet (e.g., 192.168.1.0/24)
  /// Set maxHost to higher value if you are not getting results.
  /// It won't firstHostId again unless previous scan is completed due to heavy
  /// resource consumption.
  /// [resultsInAddressAscendingOrder] = false will return results faster but not in
  /// ascending order and without [progressCallback].
  static Stream<ActiveHost> getAllPingableDevices(
    String subnet, {
    int firstHostId = 1,
    int lastHostId = 254,
    int timeoutInSeconds = 1,
    ProgressCallback? progressCallback,
    bool resultsInAddressAscendingOrder = true,
  }) async* {
    final int lastValidSubnet =
        _validateAndGetLastValidSubnet(subnet, firstHostId, lastHostId);
    final List<Future<ActiveHost?>> activeHostsFuture = [];
    final StreamController<ActiveHost> activeHostsController =
        StreamController<ActiveHost>();

    for (int i = firstHostId; i <= lastValidSubnet; i++) {
      activeHostsFuture.add(
        _getHostFromPing(
          activeHostsController: activeHostsController,
          host: '$subnet.$i',
          i: i,
          timeoutInSeconds: timeoutInSeconds,
        ),
      );
    }

    if (!resultsInAddressAscendingOrder) {
      yield* activeHostsController.stream;
    }

    int i = 0;
    for (final Future<ActiveHost?> host in activeHostsFuture) {
      i++;
      final ActiveHost? tempHost = await host;

      progressCallback
          ?.call((i - firstHostId) * 100 / (lastValidSubnet - firstHostId));

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
      final PingResponse? response = pingData.response;
      if (response != null) {
        final Duration? time = response.time;
        if (time != null) {
          final ActiveHost tempActiveHost =
              ActiveHost.buildWithAddress(address: host, pingData: pingData);
          activeHostsController.add(tempActiveHost);
          return tempActiveHost;
        }
      }
    }
    return null;
  }

  static int _validateAndGetLastValidSubnet(
      String subnet, int firstHostId, int lastHostId) {
    final int maxEnd = getMaxHost(subnet);
    if (firstHostId > lastHostId ||
        firstHostId < 1 ||
        lastHostId < 1 ||
        firstHostId > maxEnd ||
        lastHostId > maxEnd) {
      throw 'Invalid subnet range or firstHostId < lastHostId is not true';
    }
    return min(lastHostId, maxEnd);
  }

  static Stream<ActiveHost> getAllPingableDevicesAsync(
    String subnet, {
    int firstHostId = 1,
    int lastHostId = 254,
    int timeoutInSeconds = 1,
    ProgressCallback? progressCallback,
    bool resultsInAddressAscendingOrder = true,
  }) {
    final StreamController<ActiveHost> activeHostsController =
        StreamController<ActiveHost>();

    const int scanRangeForIsolate = 51;
    final int lastValidSubnet =
        _validateAndGetLastValidSubnet(subnet, firstHostId, lastHostId);
    for (int i = firstHostId;
        i <= lastValidSubnet;
        i += scanRangeForIsolate + 1) {
      final isolateManager =
          IsolateManager.createOwnIsolate(startSearchingDevices);
      final limit = min(i + scanRangeForIsolate, lastValidSubnet);
      log.fine('Scanning from $i to $limit');
      isolateManager.sendMessage(<String>[
        subnet,
        i.toString(),
        limit.toString(),
        timeoutInSeconds.toString(),
        resultsInAddressAscendingOrder.toString(),
      ]);

      isolateManager.onMessage.listen((message) {
        if (message is ActiveHost) {
          progressCallback
              ?.call((i - firstHostId) * 100 / (lastValidSubnet - firstHostId));
          activeHostsController.add(message);
        } else if (message is String && message == 'Done') {
          isolateManager.stop();
        }
      });
    }
    return activeHostsController.stream;
  }

  /// Will search devices in the network inside new isolate
  static Future<void> startSearchingDevices(dynamic params) async {
    final channel = IsolateManagerController(params);
    channel.onIsolateMessage.listen((message) async {
      List<String> paramsListString = [];
      if (message is List<String>) {
        paramsListString = message;
      } else {
        return;
      }

      final String subnetIsolate = paramsListString[0];
      final int firstSubnetIsolate = int.parse(paramsListString[1]);
      final int lastSubnetIsolate = int.parse(paramsListString[2]);
      final int timeoutInSeconds = int.parse(paramsListString[3]);
      final bool resultsInAddressAscendingOrder = paramsListString[4] == "true";

      /// Will contain all the hosts that got discovered in the network, will
      /// be use inorder to cancel on dispose of the page.
      final Stream<ActiveHost> hostsDiscoveredInNetwork =
          HostScanner.getAllPingableDevices(
        subnetIsolate,
        firstHostId: firstSubnetIsolate,
        lastHostId: lastSubnetIsolate,
        timeoutInSeconds: timeoutInSeconds,
        resultsInAddressAscendingOrder: resultsInAddressAscendingOrder,
      );

      await for (final ActiveHost activeHostFound in hostsDiscoveredInNetwork) {
        activeHostFound.deviceName.then((value) {
          activeHostFound.mdnsInfo.then((value) {
            activeHostFound.hostName.then((value) {
              channel.sendResult(activeHostFound);
            });
          });
        });
      }
      channel.sendResult('Done');
    });
  }

  /// Scans for all hosts that have the specific port that was given.
  /// [resultsInAddressAscendingOrder] = false will return results faster but not in
  /// ascending order and without [progressCallback].
  static Stream<ActiveHost> scanDevicesForSinglePort(
    String subnet,
    int port, {
    int firstHostId = 1,
    int lastHostId = 254,
    Duration timeout = const Duration(milliseconds: 2000),
    ProgressCallback? progressCallback,
    bool resultsInAddressAscendingOrder = true,
  }) async* {
    final int lastValidSubnet =
        _validateAndGetLastValidSubnet(subnet, firstHostId, lastHostId);
    final List<Future<ActiveHost?>> activeHostOpenPortList = [];
    final StreamController<ActiveHost> activeHostsController =
        StreamController<ActiveHost>();

    for (int i = firstHostId; i <= lastValidSubnet; i++) {
      final host = '$subnet.$i';
      activeHostOpenPortList.add(
        PortScanner.connectToPort(
          address: host,
          port: port,
          timeout: timeout,
          activeHostsController: activeHostsController,
        ),
      );
    }

    if (!resultsInAddressAscendingOrder) {
      yield* activeHostsController.stream;
    }

    int counter = firstHostId;
    for (final Future<ActiveHost?> openPortActiveHostFuture
        in activeHostOpenPortList) {
      final ActiveHost? activeHost = await openPortActiveHostFuture;
      if (activeHost != null) {
        yield activeHost;
      }
      progressCallback?.call(
        (counter - firstHostId) * 100 / (lastValidSubnet - firstHostId),
      );
      counter++;
    }
  }

  static const classASubnets = 16777216;
  static const classBSubnets = 65536;
  static const classCSubnets = 256;
  static int getMaxHost(String subnet) {
    if (subnet.isEmpty) {
      throw ArgumentError('Invalid subnet address, address can not be empty.');
    }
    final List<String> firstOctetStr = subnet.split('.');
    if (firstOctetStr.isEmpty) {
      throw ArgumentError(
        'Invalid subnet address, address should be in IPv4 format x.x.x',
      );
    }

    final int firstOctet = int.parse(firstOctetStr[0]);

    if (firstOctet > 0 && firstOctet < 128) {
      return classASubnets;
    } else if (firstOctet >= 128 && firstOctet < 192) {
      return classBSubnets;
    } else if (firstOctet >= 192 && firstOctet < 224) {
      return classCSubnets;
    }
    // Out of range for first octet
    throw RangeError.range(
      firstOctet,
      1,
      223,
      'subnet',
      'Out of range for first octet',
    );
  }
}
