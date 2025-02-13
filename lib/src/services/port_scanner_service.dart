import 'dart:async';

import 'package:network_tools/network_tools.dart';

/// Scans open port for a target Address or domain.
abstract class PortScannerService {
  PortScannerService() {
    _instance = this;
  }

  static late PortScannerService _instance;

  static PortScannerService get instance => _instance;

  static const int defaultStartPort = 1;
  static const int defaultEndPort = 1024;

  static const List<int> commonPorts = [
    20,
    21,
    22,
    23,
    25,
    50,
    51,
    53,
    67,
    68,
    69,
    80,
    110,
    119,
    123,
    135,
    139,
    143,
    161,
    162,
    389,
    443,
    989,
    990,
    3389,
  ];

  /// Checks if the single [port] is open or not for the [target].
  Future<ActiveHost?> isOpen(
    String target,
    int port, {
    Duration timeout = const Duration(milliseconds: 2000),
  });

  /// Scans ports only listed in [portList] for a [target]. Progress can be
  /// retrieved by [progressCallback]
  /// Tries connecting ports before until [timeout] reached.
  /// [resultsInAddressAscendingOrder] = false will return results faster but not in
  /// ascending order and without [progressCallback].
  Stream<ActiveHost> customDiscover(
    String target, {
    List<int> portList = commonPorts,
    ProgressCallback? progressCallback,
    Duration timeout = const Duration(milliseconds: 2000),
    bool resultsInAddressAscendingOrder = true,
    bool async = false,
  });

  /// Scans port from [startPort] to [endPort] of [target]. Progress can be
  /// retrieved by [progressCallback]
  /// Tries connecting ports before until [timeout] reached.
  Stream<ActiveHost> scanPortsForSingleDevice(
    String target, {
    int startPort = defaultStartPort,
    int endPort = defaultEndPort,
    ProgressCallback? progressCallback,
    Duration timeout = const Duration(milliseconds: 2000),
    bool resultsInAddressAscendingOrder = true,
    bool async = false,
  });

  Future<ActiveHost?> connectToPort({
    required String address,
    required int port,
    required Duration timeout,
    required StreamController<ActiveHost> activeHostsController,
    int recursionCount = 0,
  });
}
