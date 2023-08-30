import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:network_tools/network_tools.dart';

/// Scans for all hosts in a subnet.
class HostScannerFlutter {
  /// Scans for all hosts in a particular subnet (e.g., 192.168.1.0/24)
  /// Set maxHost to higher value if you are not getting results.
  /// It won't firstHostId again unless previous scan is completed due to heavy
  /// resource consumption.
  /// [resultsInAddressAscendingOrder] = false will return results faster but not in
  static Future<Stream<ActiveHost>> getAllPingableDevices(
    String subnet, {
    int firstHostId = HostScanner.defaultFirstHostId,
    int lastHostId = HostScanner.defaultLastHostId,
    int timeoutInSeconds = 1,
    ProgressCallback? progressCallback,
    bool resultsInAddressAscendingOrder = true,
  }) async {
    const int scanRangeForIsolate = 51;
    final StreamController<ActiveHost> activeHostsController =
        StreamController<ActiveHost>();
    final int lastValidSubnet = HostScanner.validateAndGetLastValidSubnet(
        subnet, firstHostId, lastHostId);

    for (int i = firstHostId;
        i <= lastValidSubnet;
        i += scanRangeForIsolate + 1) {
      final limit = min(i + scanRangeForIsolate, lastValidSubnet);
      final receivePort = ReceivePort();
      final isolate = await Isolate.spawn(
          HostScannerFlutter._startSearchingDevices, receivePort.sendPort);

      receivePort.listen((message) {
        if (message is SendPort) {
          message.send([
            subnet,
            i.toString(),
            limit.toString(),
            timeoutInSeconds.toString(),
            resultsInAddressAscendingOrder.toString()
          ]);
        } else if (message is ActiveHost) {
          progressCallback
              ?.call((i - firstHostId) * 100 / (lastValidSubnet - firstHostId));
          activeHostsController.add(message);
        } else if (message is String && message == 'Done') {
          isolate.kill();
        }
      });
    }
    return activeHostsController.stream;
  }

  /// Will search devices in the network inside new isolate
  // @pragma('vm:entry-point')
  static Future<void> _startSearchingDevices(SendPort sendPort) async {
    final port = ReceivePort();
    sendPort.send(port.sendPort);

    await for (List message in port) {
      final String subnetIsolate = message[0];
      final int firstSubnetIsolate = int.parse(message[1]);
      final int lastSubnetIsolate = int.parse(message[2]);
      final int timeoutInSeconds = int.parse(message[3]);
      final bool resultsInAddressAscendingOrder = message[4] == "true";

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
              sendPort.send(activeHostFound);
            });
          });
        });
      }
      sendPort.send('Done');
    }
  }
}
