import 'dart:async';
import 'dart:io';

import 'models/callbacks.dart';
import 'models/open_port.dart';

///Scans port for a target IP upto maxPort
class PortScanner {
  ///Scans port from 0 to maxPort of hostIP. Progress can be retrieved by callback
  ///Tries connecting ports before until timeout reached.
  static Stream<OpenPort> discover(
    String hostIP, {
    int maxPort = 1024,
    ProgressCallback? progressCallback,
    Duration timeout = const Duration(milliseconds: 500),
  }) async* {
    for (int i = 0; i < maxPort; ++i) {
      try {
        final Socket s = await Socket.connect(hostIP, i, timeout: timeout);
        s.destroy();
        yield OpenPort(hostIP, i, true);
      } catch (e) {
        if (!(e is SocketException)) {
          rethrow;
        }

        // Check if connection timed out or we got one of predefined errors
        if (e.osError == null || _errorCodes.contains(e.osError?.errorCode)) {
          yield OpenPort(hostIP, i, false);
        } else {
          // Error 23,24: Too many open files in system
          rethrow;
        }
      }
      progressCallback?.call(i * 100 / maxPort);
    }
  }

  static final _errorCodes = [13, 49, 61, 64, 65, 101, 111, 113];
}
