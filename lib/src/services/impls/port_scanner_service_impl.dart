import 'dart:async';
import 'dart:isolate';

import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/concurrency.dart';
import 'package:universal_io/io.dart';

/// Spawns the port scan isolate with its error and exit ports wired up.
Future<Isolate> _spawnPortScanIsolate(
  void Function(SendPort) entryPoint,
  SendPort sendPort,
  SendPort errorPort,
  SendPort exitPort,
) => Isolate.spawn(entryPoint, sendPort, onError: errorPort, onExit: exitPort);

/// Scans open port for a target Address or domain.
class PortScannerServiceImpl extends PortScannerService {
  PortScannerServiceImpl({
    Future<Isolate> Function(
      void Function(SendPort) entryPoint,
      SendPort sendPort,
      SendPort errorPort,
      SendPort exitPort,
    )?
    spawnScanIsolate,
  }) : _spawnScanIsolate = spawnScanIsolate ?? _spawnPortScanIsolate;

  /// Spawns the isolate behind [customDiscover] when `async` is true.
  ///
  /// Replaceable so tests can simulate an isolate that crashes or exits before
  /// the scan finishes.
  final Future<Isolate> Function(
    void Function(SendPort) entryPoint,
    SendPort sendPort,
    SendPort errorPort,
    SendPort exitPort,
  )
  _spawnScanIsolate;

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
    final List<InternetAddress> address = await InternetAddress.lookup(target);
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
      final errorPort = ReceivePort();
      final exitPort = ReceivePort();
      // An isolate that dies before sending 'Done' — an unresolvable target,
      // for instance — would otherwise leave this stream waiting forever.
      final errorSubscription = errorPort.listen((dynamic error) {
        receivePort.sendPort.send(<Object?>['runtimeError', error]);
      });
      final exitSubscription = exitPort.listen((dynamic _) {
        receivePort.sendPort.send(<Object?>['runtimeError', 'isolate exited']);
      });
      Isolate? isolate;

      try {
        isolate = await _spawnScanIsolate(
          _startSearchingPorts,
          receivePort.sendPort,
          errorPort.sendPort,
          exitPort.sendPort,
        );

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
          } else if (message is List && message.first == 'runtimeError') {
            throw Exception('Port scan isolate failed: ${message[1]}');
          } else if (message is String && message == 'Done') {
            break;
          } else if (message is String && message.startsWith('Error:')) {
            throw Exception(
              'Port scan isolate failed: ${message.substring(6).trim()}',
            );
          }
        }
      } finally {
        // Also runs when the consumer cancels the stream early.
        await errorSubscription.cancel();
        await exitSubscription.cancel();
        errorPort.close();
        exitPort.close();
        isolate?.kill();
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
        try {
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
        } catch (error) {
          sendPort.send('Error: $error');
        }
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
    final List<InternetAddress> address = await InternetAddress.lookup(target);
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

      if (isClosedPortError(e)) {
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

  /// Error codes that mean nothing is listening on the probed port, as opposed
  /// to the probe itself failing.
  ///
  /// A refused connect and a reset both answer "closed", but every platform
  /// numbers them differently: ECONNREFUSED is 111 on Linux/Android, 61 on
  /// Darwin and 10061 on Windows, and ECONNRESET is 104, 54 and 10054 for the
  /// same three. Darwin and Linux also answer RST instead of refusal when a
  /// port is rebound between the probe and the reply, so without the reset code
  /// a scan aborts on a port that is simply closed.
  static const Set<int> closedPortErrorCodes = <int>{
    13,
    49,
    54, // ECONNRESET, Darwin
    61, // ECONNREFUSED, Darwin
    64,
    65,
    101,
    104, // ECONNRESET, Linux
    110,
    111, // ECONNREFUSED, Linux
    113,
    10054, // WSAECONNRESET, Windows
    10060,
    10061, // WSAECONNREFUSED, Windows
    // WSAENOTCONN: Windows reports this when a pending connect is destroyed on
    // timeout, so the port never opened.
    10057,
    1225,
  };

  /// Whether [error] reports the probed port as closed rather than a failed
  /// probe; see [closedPortErrorCodes].
  static bool isClosedPortError(SocketException error) {
    // A socket error with no OS code behind it came from the Dart layer, for
    // example a connect destroyed once its timeout elapsed, so the port never
    // opened.
    final int? errorCode = error.osError?.errorCode;
    if (errorCode == null) {
      return true;
    }
    return closedPortErrorCodes.contains(errorCode) ||
        error.message.toLowerCase().contains('refused');
  }
}
