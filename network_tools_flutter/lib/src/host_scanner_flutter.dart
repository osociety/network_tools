import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:dart_ping_ios/dart_ping_ios.dart';
import 'package:network_tools/network_tools.dart';

/// Scans for all hosts in a subnet.
class HostScannerFlutter {
  /// Scans for all hosts in a particular subnet (e.g., 192.168.1.0/24)
  /// Set maxHost to higher value if you are not getting results.
  /// It won't firstHostId again unless previous scan is completed due to heavy
  /// resource consumption.
  /// [resultsInAddressAscendingOrder] = false will return results faster but not in
  static Stream<ActiveHost> getAllPingableDevices(
    String subnet, {
    int firstHostId = HostScanner.defaultFirstHostId,
    int lastHostId = HostScanner.defaultLastHostId,
    int timeoutInSeconds = 1,
    ProgressCallback? progressCallback,
    bool resultsInAddressAscendingOrder = true,
  }) async* {
    const int scanRangeForIsolate = 51;
    final int lastValidSubnet = HostScanner.validateAndGetLastValidSubnet(
        subnet, firstHostId, lastHostId);

    for (int i = firstHostId;
        i <= lastValidSubnet;
        i += scanRangeForIsolate + 1) {
      final limit = min(i + scanRangeForIsolate, lastValidSubnet);
      final receivePort = ReceivePort();
      final isolate = await Isolate.spawn(
          HostScannerFlutter._startSearchingDevices, receivePort.sendPort);
      await for (final message in  receivePort.asBroadcastStream()){
        if (message is SendPort) {
          message.send([
            subnet,
            i.toString(),
            limit.toString(),
            timeoutInSeconds.toString(),
            resultsInAddressAscendingOrder.toString()
          ]);
        } else if (message is SendableActivateHost) {
          progressCallback
              ?.call((i - firstHostId) * 100 / (lastValidSubnet - firstHostId));
           final activeHostFound = ActiveHost.fromSendableActiveHost(sendableActivateHost: message);
         await activeHostFound.resolveInfo(); 
         yield activeHostFound;
        } else if (message is String && message == 'Done') {
          isolate.kill();
        }
      }
    }
  }

  /// Will search devices in the network inside new isolate
  @pragma('vm:entry-point')
  static Future<void> _startSearchingDevices(SendPort sendPort) async {
    DartPingIOS.register();
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
      final Stream<SendableActivateHost> hostsDiscoveredInNetwork =
          HostScanner.getAllSendablePingableDevices(
        subnetIsolate,
        firstHostId: firstSubnetIsolate,
        lastHostId: lastSubnetIsolate,
        timeoutInSeconds: timeoutInSeconds,
        resultsInAddressAscendingOrder: resultsInAddressAscendingOrder,
      );

      await for (final SendableActivateHost activeHostFound in hostsDiscoveredInNetwork) {
        sendPort.send(activeHostFound);
      }
      sendPort.send('Done');
    }
  }
}
