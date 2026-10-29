import 'dart:async';
import 'dart:isolate';

import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/concurrency.dart';
import 'package:universal_io/io.dart';

/// Scans open port for a target Address or domain.
class PortScannerServiceImpl extends PortScannerService {
  /// Checks if the single [port] is open or not for the [target].
  ///
  /// Returns an [ActiveHost] if the port is open, otherwise null.
  /// Throws if the port is out of range or the target cannot be resolved.
  @override
  Future<ActiveHost?> isOpen(
    String target,
    int port, {
    Duration timeout = const Duration(milliseconds: 2000),
  }) async {
    if (port < 0 || port > 65535) {
      throw 'Provide a valid port range between '
          '0 to 65535 or startPort < endPort is not true';
    }
    final List<InternetAddress> address = await InternetAddress.lookup(
      target,
      type: InternetAddressType.IPv4,
    );
    if (address.isNotEmpty) {
      final String hostAddress = address[0].address;
      return await connectToPort(
        address: hostAddress,
        port: port,
        timeout: timeout,
      );
    } else {
      throw 'Name can not be resolved';
    }
  }

  /// Scans only the ports listed in [portList] for a [target].
  ///
  /// Progress can be retrieved by [progressCallback].
  /// Tries connecting ports until [timeout] is reached for each port.
  /// If [resultsInAddressAscendingOrder] is false, results may be returned faster but not in ascending order.
  /// If [async] is true, scanning is performed in an isolate.
  /// [maxConcurrency] limits how many ports are probed at the same time.
  @override
  Stream<ActiveHost> customDiscover(
    String target, {
    List<int> portList = PortScannerService.commonPorts,
    ProgressCallback? progressCallback,
    Duration timeout = const Duration(milliseconds: 2000),
    bool resultsInAddressAscendingOrder = true,
    bool async = false,
    int maxConcurrency = PortScannerService.defaultMaxConcurrency,
  }) async* {
    if (!async) {
      // If async is false then run on main isolate
      yield* _customDiscover<ActiveHost>(
        target,
        portList: portList,
        progressCallback: progressCallback,
        timeout: timeout,
        resultsInAddressAscendingOrder: resultsInAddressAscendingOrder,
        maxConcurrency: maxConcurrency,
      );
    } else {
      final receivePort = ReceivePort();
      final isolate = await Isolate.spawn(
        _startSearchingPorts,
        receivePort.sendPort,
      );

      try {
        await for (final message in receivePort) {
          if (message is SendPort) {
            message.send(<dynamic>[
              target,
              portList,
              timeout,
              resultsInAddressAscendingOrder.toString(),
              maxConcurrency,
            ]);
          } else if (message is SendableActiveHost) {
            // Resolution is lazy on ActiveHost, so result creation stays cheap.
            yield ActiveHost.fromSendableActiveHost(
              sendableActiveHost: message,
            );
          } else if (message is List && message.first == 'progress') {
            progressCallback?.call((message[1] as num).toDouble());
          } else if (message is String && message == 'Done') {
            break;
          }
        }
      } finally {
        // Also runs when the consumer cancels the stream early.
        isolate.kill();
        receivePort.close();
      }
    }
  }

  @pragma('vm:entry-point')
  Future<void> _startSearchingPorts(SendPort sendPort) async {
    final port = ReceivePort();
    sendPort.send(port.sendPort);

    await for (final message in port) {
      if (message is List<dynamic>) {
        final String target = message[0] as String;
        final List<int> portList = message[1] as List<int>;
        final Duration timeout = message[2] as Duration;
        final bool resultsInAddressAscendingOrder = message[3] == "true";
        final int maxConcurrency = message[4] as int;

        double lastProgress = -1;
        final openPortsForTarget = _customDiscover<SendableActiveHost>(
          target,
          portList: portList,
          timeout: timeout,
          resultsInAddressAscendingOrder: resultsInAddressAscendingOrder,
          maxConcurrency: maxConcurrency,
          progressCallback: (double progress) {
            // Avoid flooding the main isolate with one message per port.
            if ((progress - lastProgress).abs() >= 1) {
              lastProgress = progress;
              sendPort.send(<dynamic>['progress', progress]);
            }
          },
        );

        await for (final SendableActiveHost activeHostFound
            in openPortsForTarget) {
          sendPort.send(activeHostFound);
        }
        sendPort.send('Done');
      }
    }
  }

  Stream<T> _customDiscover<T>(
    String target, {
    List<int> portList = PortScannerService.commonPorts,
    ProgressCallback? progressCallback,
    Duration timeout = const Duration(milliseconds: 2000),
    bool resultsInAddressAscendingOrder = true,
    int maxConcurrency = PortScannerService.defaultMaxConcurrency,
  }) async* {
    final List<InternetAddress> address = await InternetAddress.lookup(
      target,
      type: InternetAddressType.IPv4,
    );
    if (address.isEmpty) {
      throw 'Name can not be resolved';
    }
    final String hostAddress = address[0].address;
    final List<int> ports = portList
        .where((int port) => port >= 0 && port <= 65535)
        .toList();
    if (ports.isEmpty) {
      return;
    }

    // A bounded pool keeps the number of open sockets low. Without it, a full
    // 0-65535 scan opens tens of thousands of sockets at once, hits the
    // file-descriptor limit and falls back to slow retries.
    final Stream<ConcurrentResult<T>> results = mapConcurrently<int, T>(
      ports,
      (int port) =>
          _connectToPort<T>(address: hostAddress, port: port, timeout: timeout),
      maxConcurrency: maxConcurrency,
      onCompleted: (int completed) =>
          progressCallback?.call(completed * 100 / ports.length),
    );

    if (!resultsInAddressAscendingOrder) {
      await for (final ConcurrentResult<T> result in results) {
        final T? value = result.value;
        if (value != null) {
          yield value;
        }
      }
      return;
    }

    // Results complete out of order; buffer them and emit by port index so the
    // ascending-order contract is preserved while still running in parallel.
    final Map<int, T?> pending = <int, T?>{};
    int nextIndex = 0;
    await for (final ConcurrentResult<T> result in results) {
      pending[result.index] = result.value;
      while (pending.containsKey(nextIndex)) {
        final T? value = pending.remove(nextIndex);
        nextIndex++;
        if (value != null) {
          yield value;
        }
      }
    }
  }

  /// Scans ports from [startPort] to [endPort] for a [target].
  ///
  /// Progress can be retrieved by [progressCallback].
  /// Tries connecting ports until [timeout] is reached for each port.
  /// If [resultsInAddressAscendingOrder] is false, results may be returned faster but not in ascending order.
  /// If [async] is true, scanning is performed in an isolate.
  /// [maxConcurrency] limits how many ports are probed at the same time.
  @override
  Stream<ActiveHost> scanPortsForSingleDevice(
    String target, {
    int startPort = PortScannerService.defaultStartPort,
    int endPort = PortScannerService.defaultEndPort,
    ProgressCallback? progressCallback,
    Duration timeout = const Duration(milliseconds: 2000),
    bool resultsInAddressAscendingOrder = true,
    bool async = false,
    int maxConcurrency = PortScannerService.defaultMaxConcurrency,
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
      maxConcurrency: maxConcurrency,
    );
  }

  /// Attempts to connect to a specific [port] on an [address] within a [timeout].
  ///
  /// Returns an [ActiveHost] if the port is open, otherwise null. Used internally.
  @override
  Future<ActiveHost?> connectToPort({
    required String address,
    required int port,
    required Duration timeout,
    StreamController<ActiveHost>? activeHostsController,
    int recursionCount = 0,
  }) async {
    return await _connectToPort<ActiveHost>(
      address: address,
      port: port,
      timeout: timeout,
      activeHostsController: activeHostsController,
    );
  }

  Future<T?> _connectToPort<T>({
    required String address,
    required int port,
    required Duration timeout,
    StreamController<T>? activeHostsController,
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
        if (activeHostsController != null && !activeHostsController.isClosed) {
          activeHostsController.add(sendableActiveHost as T);
        }
        return sendableActiveHost as T;
      }
      final ActiveHost activeHost = ActiveHost.buildWithAddress(
        address: address,
        openPorts: [OpenPort(port)],
      );
      if (activeHostsController != null && !activeHostsController.isClosed) {
        activeHostsController.add(activeHost as T);
      }
      return activeHost as T;
    } catch (e) {
      if (e is! SocketException) {
        rethrow;
      }

      // Check if connection timed out or we got one of predefined errors.
      // Windows can surface refusal errors with different codes/messages, so
      // treat those as closed ports as well.
      final errorCode = e.osError?.errorCode;
      if (e.osError == null ||
          _errorCodes.contains(errorCode) ||
          e.message.toLowerCase().contains('refused')) {
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

        return await _connectToPort<T>(
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

  final _errorCodes = [
    13,
    49,
    61,
    64,
    65,
    101,
    110,
    111,
    113,
    10060,
    10061,
    // WSAENOTCONN: Windows reports this when a pending connect is destroyed on
    // timeout, so the port never opened.
    10057,
    1225,
  ];
}
