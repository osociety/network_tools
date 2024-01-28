import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:network_tools/network_tools.dart';
import 'package:universal_io/io.dart';

/// Scans open port for a target Address or domain.
class PortScanner {
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
  static Future<ActiveHost?> isOpen(
    String target,
    int port, {
    Duration timeout = const Duration(milliseconds: 2000),
  }) async {
    if (port < 0 || port > 65535) {
      throw 'Provide a valid port range between '
          '0 to 65535 or startPort < endPort is not true';
    }
    final List<InternetAddress> address =
        await InternetAddress.lookup(target, type: InternetAddressType.IPv4);
    if (address.isNotEmpty) {
      final String hostAddress = address[0].address;
      return connectToPort(
        activeHostsController: StreamController<ActiveHost>(),
        address: hostAddress,
        port: port,
        timeout: timeout,
      );
    } else {
      throw 'Name can not be resolved';
    }
  }

  /// Scans ports only listed in [portList] for a [target]. Progress can be
  /// retrieved by [progressCallback]
  /// Tries connecting ports before until [timeout] reached.
  /// [resultsInAddressAscendingOrder] = false will return results faster but not in
  /// ascending order and without [progressCallback].
  static Stream<ActiveHost> customDiscover(
    String target, {
    List<int> portList = commonPorts,
    ProgressCallback? progressCallback,
    Duration timeout = const Duration(milliseconds: 2000),
    bool resultsInAddressAscendingOrder = true,
    bool async = false,
  }) async* {
    if (async) {
      yield* _customDiscover<ActiveHost>(
        target,
        portList: portList,
        progressCallback: progressCallback,
        timeout: timeout,
        resultsInAddressAscendingOrder: resultsInAddressAscendingOrder,
      );
    } else {
      const int scanRangeForIsolate = 1000;
      for (int i = 0; i <= portList.length; i += scanRangeForIsolate + 1) {
        final limit = min(i + scanRangeForIsolate, portList.length);
        final receivePort = ReceivePort();
        final isolate =
            await Isolate.spawn(_startSearchingPorts, receivePort.sendPort);

        await for (final message in receivePort) {
          if (message is SendPort) {
            message.send(
              <dynamic>[
                target,
                portList.sublist(i, limit),
                timeout,
                resultsInAddressAscendingOrder.toString(),
                dbDirectory,
                enableDebugging.toString(),
              ],
            );
          } else if (message is SendableActiveHost) {
            progressCallback?.call(i * 100 / (portList.length));
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
  }

  /// Will search devices in the network inside new isolate
  @pragma('vm:entry-point')
  static Future<void> _startSearchingPorts(SendPort sendPort) async {
    final port = ReceivePort();
    sendPort.send(port.sendPort);

    await for (final message in port) {
      if (message is List<dynamic>) {
        final String target = message[0] as String;
        final List<int> portList = message[1] as List<int>;
        final Duration timeout = message[2] as Duration;
        final bool resultsInAddressAscendingOrder = message[3] == "true";
        final String dbDirectory = message[4] as String;
        final bool enableDebugging = message[5] == "true";
        // configure again
        await configureNetworkTools(
          dbDirectory,
          enableDebugging: enableDebugging,
        );
        final openPortsForTarget = _customDiscover<SendableActiveHost>(
          target,
          portList: portList,
          timeout: timeout,
          resultsInAddressAscendingOrder: resultsInAddressAscendingOrder,
        );

        await for (final SendableActiveHost activeHostFound
            in openPortsForTarget) {
          sendPort.send(activeHostFound);
        }
        sendPort.send('Done');
      }
    }
  }

  static Stream<T> _customDiscover<T>(
    String target, {
    List<int> portList = commonPorts,
    ProgressCallback? progressCallback,
    Duration timeout = const Duration(milliseconds: 2000),
    bool resultsInAddressAscendingOrder = true,
  }) async* {
    final List<InternetAddress> address =
        await InternetAddress.lookup(target, type: InternetAddressType.IPv4);
    if (address.isNotEmpty) {
      final String hostAddress = address[0].address;
      final List<Future<T?>> openPortList = [];
      final StreamController<T> activeHostsController = StreamController<T>();

      for (int k = 0; k < portList.length; k++) {
        if (portList[k] >= 0 && portList[k] <= 65535) {
          openPortList.add(
            _connectToPort<T>(
              address: hostAddress,
              port: portList[k],
              timeout: timeout,
              activeHostsController: activeHostsController,
            ),
          );
        }
      }

      if (!resultsInAddressAscendingOrder) {
        yield* activeHostsController.stream;
      }

      int counter = 0;

      for (final Future<T?> openPortFuture in openPortList) {
        final T? openPort = await openPortFuture;
        if (openPort == null) {
          continue;
        }
        progressCallback?.call(counter * 100 / portList.length);
        yield openPort;
        counter++;
      }
    } else {
      throw 'Name can not be resolved';
    }
  }

  /// Scans port from [startPort] to [endPort] of [target]. Progress can be
  /// retrieved by [progressCallback]
  /// Tries connecting ports before until [timeout] reached.
  static Stream<ActiveHost> scanPortsForSingleDevice(
    String target, {
    int startPort = defaultStartPort,
    int endPort = defaultEndPort,
    ProgressCallback? progressCallback,
    Duration timeout = const Duration(milliseconds: 2000),
    bool resultsInAddressAscendingOrder = true,
    bool async = false,
  }) async* {
    if (startPort < 0 ||
        endPort < 0 ||
        startPort > 65535 ||
        endPort > 65535 ||
        startPort > endPort) {
      throw 'Provide a valid port range between 0 to 65535 or startPort <'
          ' endPort is not true';
    }

    final List<int> portList = [];

    for (int i = startPort; i <= endPort; ++i) {
      portList.add(i);
    }

    yield* customDiscover(
      target,
      portList: portList,
      progressCallback: progressCallback,
      timeout: timeout,
      resultsInAddressAscendingOrder: resultsInAddressAscendingOrder,
      async: async,
    );
  }

  static Future<ActiveHost?> connectToPort({
    required String address,
    required int port,
    required Duration timeout,
    required StreamController<ActiveHost> activeHostsController,
    int recursionCount = 0,
  }) async {
    return _connectToPort<ActiveHost>(
      address: address,
      port: port,
      timeout: timeout,
      activeHostsController: activeHostsController,
    );
  }

  static Future<T?> _connectToPort<T>({
    required String address,
    required int port,
    required Duration timeout,
    required StreamController<T> activeHostsController,
    int recursionCount = 0,
  }) async {
    try {
      final Socket s = await Socket.connect(address, port, timeout: timeout);
      s.destroy();

      if (T == SendableActiveHost) {
        final SendableActiveHost sendableActiveHost = SendableActiveHost(
          address,
          openPorts: [OpenPort(port)],
        );
        activeHostsController.add(sendableActiveHost as T);
        return sendableActiveHost as T;
      }
      final ActiveHost activeHost = ActiveHost.buildWithAddress(
        address: address,
        openPorts: [OpenPort(port)],
      );
      activeHostsController.add(activeHost as T);
      return activeHost as T;
    } catch (e) {
      if (e is! SocketException) {
        rethrow;
      }

      // Check if connection timed out or we got one of predefined errors
      if (e.osError == null || _errorCodes.contains(e.osError?.errorCode)) {
        return null;
      }

      // Error 23,24: Too many open files in system
      // e.osError can't be null here so `!` can be used
      // Do no more than 2 retries to prevent infinite loops
      if (recursionCount < 3 &&
          (e.osError!.errorCode == 23 || e.osError!.errorCode == 24)) {
        // Hotfix: Wait for the timeout (+ a little more) to complete and retry
        // -> Other connections must be closed now and the file handles available again

        await Future.delayed(timeout + const Duration(milliseconds: 250));

        return _connectToPort<T>(
          address: address,
          port: port,
          timeout: timeout,
          activeHostsController: activeHostsController,
          recursionCount: recursionCount + 1,
        );
      }

      rethrow;
    }
  }

  static final _errorCodes = [13, 49, 61, 64, 65, 101, 111, 113];
}
