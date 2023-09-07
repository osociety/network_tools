import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:dart_ping/dart_ping.dart';
import 'package:network_tools/src/models/active_host.dart';
import 'package:network_tools/src/models/callbacks.dart';
import 'package:network_tools/src/models/sendable_active_host.dart';
import 'package:network_tools/src/network_tools_utils.dart';
import 'package:network_tools/src/port_scanner.dart';

/// Scans for all hosts in a subnet.
class HostScanner {
  /// Devices scan will start from this integer Id
  static const int defaultFirstHostId = 1;

  /// Devices scan will stop at this integer id
  static const int defaultLastHostId = 254;

  /// Scans for all hosts in a particular subnet (e.g., 192.168.1.0/24)
  /// Set maxHost to higher value if you are not getting results.
  /// It won't firstHostId again unless previous scan is completed due to heavy
  /// resource consumption.
  /// [resultsInAddressAscendingOrder] = false will return results faster but not in
  /// ascending order and without [progressCallback].
  static Stream<ActiveHost> getAllPingableDevices(
    String subnet, {
    int firstHostId = defaultFirstHostId,
    int lastHostId = defaultLastHostId,
    int timeoutInSeconds = 1,
    ProgressCallback? progressCallback,
    bool resultsInAddressAscendingOrder = true,
  }) async* {
    final stream = getAllSendablePingableDevices(
      subnet,
      firstHostId: firstHostId,
      lastHostId: lastHostId,
      timeoutInSeconds: timeoutInSeconds,
      progressCallback: progressCallback,
      resultsInAddressAscendingOrder: resultsInAddressAscendingOrder,
    );
    await for (final sendableActiveHost in stream) {
      final activeHost = ActiveHost.fromSendableActiveHost(
        sendableActiveHost: sendableActiveHost,
      );

      await activeHost.resolveInfo();

      yield activeHost;
    }
  }

  /// Same as [getAllPingableDevices] but can be called or run inside isolate.
  static Stream<SendableActiveHost> getAllSendablePingableDevices(
    String subnet, {
    int firstHostId = defaultFirstHostId,
    int lastHostId = defaultLastHostId,
    int timeoutInSeconds = 1,
    ProgressCallback? progressCallback,
    bool resultsInAddressAscendingOrder = true,
  }) async* {
    final int lastValidSubnet =
        validateAndGetLastValidSubnet(subnet, firstHostId, lastHostId);
    final List<Future<SendableActiveHost?>> activeHostsFuture = [];
    final StreamController<SendableActiveHost> activeHostsController =
        StreamController<SendableActiveHost>();

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
    for (final Future<SendableActiveHost?> host in activeHostsFuture) {
      i++;
      final SendableActiveHost? tempHost = await host;

      progressCallback
          ?.call((i - firstHostId) * 100 / (lastValidSubnet - firstHostId));

      if (tempHost == null) {
        continue;
      }
      yield tempHost;
    }
  }

  static Future<SendableActiveHost?> _getHostFromPing({
    required String host,
    required int i,
    required StreamController<SendableActiveHost> activeHostsController,
    int timeoutInSeconds = 1,
  }) async {
    await for (final PingData pingData
        in Ping(host, count: 1, timeout: timeoutInSeconds).stream) {
      final PingResponse? response = pingData.response;
      final PingError? pingError = pingData.error;
      if (response != null && pingError == null) {
        final Duration? time = response.time;
        if (time != null) {
          final tempSendableActivateHost = SendableActiveHost(host, pingData);
          activeHostsController.add(tempSendableActivateHost);
          return tempSendableActivateHost;
        }
      }
    }
    return null;
  }

  static int validateAndGetLastValidSubnet(
    String subnet,
    int firstHostId,
    int lastHostId,
  ) {
    final int maxEnd = maxHost;
    if (firstHostId > lastHostId ||
        firstHostId < defaultFirstHostId ||
        lastHostId < defaultFirstHostId ||
        firstHostId > maxEnd ||
        lastHostId > maxEnd) {
      throw 'Invalid subnet range or firstHostId < lastHostId is not true';
    }
    return min(lastHostId, maxEnd);
  }

  /// Works same as [getAllPingableDevices] but does everything inside
  /// isolate out of the box.
  static Stream<ActiveHost> getAllPingableDevicesAsync(
    String subnet, {
    int firstHostId = defaultFirstHostId,
    int lastHostId = defaultLastHostId,
    int timeoutInSeconds = 1,
    ProgressCallback? progressCallback,
    bool resultsInAddressAscendingOrder = true,
  }) async* {
    const int scanRangeForIsolate = 51;
    final int lastValidSubnet =
        validateAndGetLastValidSubnet(subnet, firstHostId, lastHostId);
    for (int i = firstHostId;
        i <= lastValidSubnet;
        i += scanRangeForIsolate + 1) {
      final limit = min(i + scanRangeForIsolate, lastValidSubnet);
      log.fine('Scanning from $i to $limit');

      final receivePort = ReceivePort();
      final isolate =
          await Isolate.spawn(_startSearchingDevices, receivePort.sendPort);

      await for (final message in receivePort) {
        if (message is SendPort) {
          message.send(<String>[
            subnet,
            i.toString(),
            limit.toString(),
            timeoutInSeconds.toString(),
            resultsInAddressAscendingOrder.toString(),
          ]);
        } else if (message is SendableActiveHost) {
          progressCallback
              ?.call((i - firstHostId) * 100 / (lastValidSubnet - firstHostId));
          final activeHostFound =
              ActiveHost.fromSendableActiveHost(sendableActiveHost: message);
          await activeHostFound.resolveInfo();
          yield activeHostFound;
        } else if (message is String && message == 'Done') {
          isolate.kill();
          break;
        }
      }
    }
  }

  /// Will search devices in the network inside new isolate
  @pragma('vm:entry-point')
  static Future<void> _startSearchingDevices(SendPort sendPort) async {
    final port = ReceivePort();
    sendPort.send(port.sendPort);

    await for (final message in port) {
      if (message is List<String>) {
        final String subnetIsolate = message[0];
        final int firstSubnetIsolate = int.parse(message[1]);
        final int lastSubnetIsolate = int.parse(message[2]);
        final int timeoutInSeconds = int.parse(message[3]);
        final bool resultsInAddressAscendingOrder = message[4] == "true";

        /// Will contain all the hosts that got discovered in the network, will
        /// be use inorder to cancel on dispose of the page.
        final Stream<SendableActiveHost> hostsDiscoveredInNetwork =
            HostScanner.getAllSendablePingableDevices(
          subnetIsolate,
          firstHostId: firstSubnetIsolate,
          lastHostId: lastSubnetIsolate,
          timeoutInSeconds: timeoutInSeconds,
          resultsInAddressAscendingOrder: resultsInAddressAscendingOrder,
        );

        await for (final SendableActiveHost activeHostFound
            in hostsDiscoveredInNetwork) {
          sendPort.send(activeHostFound);
        }
        sendPort.send('Done');
      }
    }
  }

  /// Scans for all hosts that have the specific port that was given.
  /// [resultsInAddressAscendingOrder] = false will return results faster but not in
  /// ascending order and without [progressCallback].
  static Stream<ActiveHost> scanDevicesForSinglePort(
    String subnet,
    int port, {
    int firstHostId = defaultFirstHostId,
    int lastHostId = defaultLastHostId,
    Duration timeout = const Duration(milliseconds: 2000),
    ProgressCallback? progressCallback,
    bool resultsInAddressAscendingOrder = true,
  }) async* {
    final int lastValidSubnet =
        validateAndGetLastValidSubnet(subnet, firstHostId, lastHostId);
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

  /// Defines total number of subnets in class A network
  static const classASubnets = 16777216;

  /// Defines total number of subnets in class B network
  static const classBSubnets = 65536;

  /// Defines total number of subnets in class C network
  static const classCSubnets = 256;

  /// Minimum value of first octet in IPv4 address used by getMaxHost
  static const int minNetworkId = 1;

  /// Maximum value of first octect in IPv4 address used by getMaxHost
  static const int maxNetworkId = 223;

  /// returns the max number of hosts a subnet can have excluding network Id and broadcast Id
  @Deprecated(
    "Implementation is wrong, since we only append in last octet, max host can only be 254. Use maxHost getter",
  )
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

    if (firstOctet >= minNetworkId && firstOctet < 128) {
      return classASubnets;
    } else if (firstOctet >= 128 && firstOctet < 192) {
      return classBSubnets;
    } else if (firstOctet >= 192 && firstOctet <= maxNetworkId) {
      return classCSubnets;
    }
    // Out of range for first octet
    throw RangeError.range(
      firstOctet,
      minNetworkId,
      maxNetworkId,
      'subnet',
      'Out of range for first octet',
    );
  }

  static int get maxHost => defaultLastHostId;
}
