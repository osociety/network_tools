import 'package:mockito/mockito.dart';
import 'package:network_tools/network_tools.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';
import '../lib/src/host_scanner.mocks.dart';

void main() {
  group('Testing Host Scanner', () {
    final mockHostScanner = MockHostScanner();
    test('Running getAllPingableDevices tests', () {
      final activeHost =
          ActiveHost(internetAddress: InternetAddress("10.0.0.1"));
      when(mockHostScanner.getAllPingableDevices("10.0.0"))
          .thenAnswer((_) => Stream.value(activeHost));
      expect(
        mockHostScanner.getAllPingableDevices("10.0.0"),
        emits(ActiveHost(internetAddress: InternetAddress("10.0.0.1"))),
      );
    });
  });
}
