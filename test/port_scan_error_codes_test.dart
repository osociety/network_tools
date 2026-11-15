// Classification of the socket errors a port probe can get back, which decides
// whether a scan reports a closed port or aborts.
//
// The reset codes matter most here: a runner that rebinds an ephemeral port
// between the probe and the reply answers with RST instead of a refusal, and
// that used to be rethrown out of the scan.

import 'dart:io';

import 'package:network_tools/src/services/impls/port_scanner_service_impl.dart';
import 'package:test/test.dart';

SocketException _error(String message, int errorCode) =>
    SocketException(message, osError: OSError(message, errorCode));

void main() {
  group('closed port classification', () {
    test('lists every platform closed-port code and nothing else', () {
      expect(PortScannerServiceImpl.closedPortErrorCodes, <int>{
        13,
        49,
        54, // ECONNRESET, Darwin
        61, // ECONNREFUSED, Darwin
        64,
        65,
        101,
        104, // ECONNRESET, Linux
        110,
        111, // ECONNREFUSED, Linux/Android
        113,
        10054, // WSAECONNRESET, Windows
        10057, // WSAENOTCONN, Windows
        10060,
        10061, // WSAECONNREFUSED, Windows
        1225,
      });
    });

    test('reports a reset as a closed port on every platform', () {
      expect(
        PortScannerServiceImpl.isClosedPortError(
          _error('Connection reset by peer', 54),
        ),
        isTrue,
        reason: 'macOS and iOS report ECONNRESET as 54',
      );
      expect(
        PortScannerServiceImpl.isClosedPortError(
          _error('Connection reset by peer', 104),
        ),
        isTrue,
        reason: 'Linux and Android report ECONNRESET as 104',
      );
      expect(
        PortScannerServiceImpl.isClosedPortError(
          _error(
            'An existing connection was forcibly closed by the remote host',
            10054,
          ),
        ),
        isTrue,
        reason: 'Windows reports WSAECONNRESET as 10054',
      );
    });

    test('reports a refusal as closed whatever code the OS attached', () {
      expect(
        PortScannerServiceImpl.isClosedPortError(
          _error('Connection refused', 9999),
        ),
        isTrue,
      );
    });

    test('reports a failure with no OS error as closed', () {
      expect(
        PortScannerServiceImpl.isClosedPortError(
          const SocketException('Connection timed out'),
        ),
        isTrue,
        reason: 'a connect destroyed on timeout never opened the port',
      );
    });

    test('leaves the descriptor exhaustion errors to the retry path', () {
      expect(
        PortScannerServiceImpl.isClosedPortError(
          _error('Too many open files in system', 23),
        ),
        isFalse,
      );
      expect(
        PortScannerServiceImpl.isClosedPortError(
          _error('Too many open files', 24),
        ),
        isFalse,
      );
    });
  });
}
