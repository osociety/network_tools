import 'dart:async';

import 'package:dart_ping_ios/dart_ping_ios.dart';
import 'package:network_tools/network_tools.dart';

/// Flutter flavor of PortScanner, only use if your project is based of flutter.
class PortScannerFlutter {

  /// Checks if the single [port] is open or not for the [target].
  static Future<ActiveHost?> isOpen(
    String target,
    int port, {
    Duration timeout = const Duration(milliseconds: 2000),
  }){
    DartPingIOS.register();
    return PortScanner.isOpen(target, port);
  }

  /// Scans ports only listed in [portList] for a [target]. Progress can be
  /// retrieved by [progressCallback]
  /// Tries connecting ports before until [timeout] reached.
  /// [resultsInAddressAscendingOrder] = false will return results faster but not in
  /// ascending order and without [progressCallback].
  static Stream<ActiveHost> customDiscover(
    String target, {
    List<int> portList = PortScanner.commonPorts,
    ProgressCallback? progressCallback,
    Duration timeout = const Duration(milliseconds: 2000),
    bool resultsInAddressAscendingOrder = true,
  }) {
    DartPingIOS.register();
    return PortScanner.customDiscover(target);
  }

  /// Scans port from [startPort] to [endPort] of [target]. Progress can be
  /// retrieved by [progressCallback]
  /// Tries connecting ports before until [timeout] reached.
  static Stream<ActiveHost> scanPortsForSingleDevice(
    String target, {
    int startPort = PortScanner.defaultEndPort,
    int endPort = PortScanner.defaultEndPort,
    ProgressCallback? progressCallback,
    Duration timeout = const Duration(milliseconds: 2000),
    bool resultsInAddressAscendingOrder = true,
  }){
    DartPingIOS.register();
    return PortScanner.scanPortsForSingleDevice(target);
  }

  static Future<ActiveHost?> connectToPort({
    required String address,
    required int port,
    required Duration timeout,
    required StreamController<ActiveHost> activeHostsController,
    int recursionCount = 0,
  }) async {
    DartPingIOS.register();
    return PortScanner.connectToPort(address: address, port: port, timeout: timeout,
     activeHostsController: activeHostsController);
  }
}