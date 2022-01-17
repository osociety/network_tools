import 'dart:async';
import 'dart:io';

import 'models/callbacks.dart';
import 'models/open_port.dart';

/// Scans open port for a target IP or domain.
class PortScanner {
  static const int defaultStartPort = 0;
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
    3389
  ];

  /// Checks if the single [port] is open or not for the [target].
  static Future<OpenPort> isOpen(
    String target,
    int port, {
    Duration timeout = const Duration(milliseconds: 500),
  }) async {
    if (port < 0 || port > 65535) {
      throw 'Provide a valid port range between '
          '0 to 65535 or startPort < endPort is not true';
    }
    final List<InternetAddress> address =
        await InternetAddress.lookup(target, type: InternetAddressType.IPv4);
    if (address.isNotEmpty) {
      final String hostIP = address[0].address;
      return connectToPort(hostIP, port, timeout);
    } else {
      throw 'Name can not be resolved';
    }
  }

  /// Scans ports only listed in [portList] for a [target]. Progress can be
  /// retrieved by [progressCallback]
  /// Tries connecting ports before until [timeout] reached.
  static Stream<OpenPort> customDiscover(
    String target, {
    List<int> portList = commonPorts,
    ProgressCallback? progressCallback,
    Duration timeout = const Duration(milliseconds: 500),
  }) async* {
    final List<InternetAddress> address =
        await InternetAddress.lookup(target, type: InternetAddressType.IPv4);
    if (address.isNotEmpty) {
      final String hostIP = address[0].address;
      for (int k = 0; k < portList.length; k++) {
        print('Checking for port ${portList[k]}');
        if (portList[k] >= 0 && portList[k] <= 65535) {
          yield await connectToPort(hostIP, portList[k], timeout);
        }
        progressCallback?.call(k * 100 / portList.length);
      }
      print('Port Scan completed');
    } else {
      throw 'Name can not be resolved';
    }
  }

  /// Scans port from [startPort] to [endPort] of [target]. Progress can be
  /// retrieved by [progressCallback]
  /// Tries connecting ports before until [timeout] reached.
  static Stream<OpenPort> discover(
    String target, {
    int startPort = defaultStartPort,
    int endPort = defaultEndPort,
    ProgressCallback? progressCallback,
    Duration timeout = const Duration(milliseconds: 500),
  }) async* {
    if (startPort < 0 ||
        endPort < 0 ||
        startPort > 65535 ||
        endPort > 65535 ||
        startPort > endPort) {
      throw 'Provide a valid port range between 0 to 65535 or startPort <'
          ' endPort is not true';
    }

    final List<InternetAddress> address =
        await InternetAddress.lookup(target, type: InternetAddressType.IPv4);
    if (address.isNotEmpty) {
      final String hostIP = address[0].address;
      for (int i = startPort; i <= endPort; ++i) {
        print('Checking for port $i');
        yield await connectToPort(hostIP, i, timeout);
        progressCallback?.call((i - startPort) * 100 / (endPort - startPort));
      }
      print('Port Scan completed');
    } else {
      throw 'Name can not be resolved';
    }
  }

  static Future<OpenPort> connectToPort(
    String ip,
    int port,
    Duration timeout,
  ) async {
    try {
      final Socket s = await Socket.connect(ip, port, timeout: timeout);
      s.destroy();
      return OpenPort(ip, port, true);
    } catch (e) {
      if (e is! SocketException) {
        rethrow;
      }

      // Check if connection timed out or we got one of predefined errors
      if (e.osError == null || _errorCodes.contains(e.osError?.errorCode)) {
        return OpenPort(ip, port, false);
      } else {
        // Error 23,24: Too many open files in system
        rethrow;
      }
    }
  }

  static final _errorCodes = [13, 49, 61, 64, 65, 101, 111, 113];
}
