import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/services/impls/host_scanner_service_impl.dart';
import 'package:test/test.dart';

void main() {
  group('Device Type Inference', () {
    late HostScannerServiceImpl scanner;

    setUp(() {
      scanner = HostScannerServiceImpl();
    });

    test('infers Router from DNS + SNMP ports', () {
      final ports = [OpenPort(53), OpenPort(161), OpenPort(80)];
      final result = scanner.testInferDeviceType(ports);
      expect(result, equals('Router'));
    });

    test('infers Printer from IPP port', () {
      final ports = [OpenPort(631)];
      final result = scanner.testInferDeviceType(ports);
      expect(result, equals('Printer'));
    });

    test('infers Printer from JetDirect port', () {
      final ports = [OpenPort(9100)];
      final result = scanner.testInferDeviceType(ports);
      expect(result, equals('Printer'));
    });

    test('infers Windows PC from SMB port', () {
      final ports = [OpenPort(445)];
      final result = scanner.testInferDeviceType(ports);
      expect(result, equals('Windows PC'));
    });

    test('infers Windows PC from RDP port', () {
      final ports = [OpenPort(3389)];
      final result = scanner.testInferDeviceType(ports);
      expect(result, equals('Windows PC'));
    });

    test('infers NAS from FTP + SMB ports', () {
      final ports = [OpenPort(21), OpenPort(445)];
      final result = scanner.testInferDeviceType(ports);
      expect(result, equals('NAS'));
    });

    test('infers Linux Server from SSH + HTTP ports', () {
      final ports = [OpenPort(22), OpenPort(80)];
      final result = scanner.testInferDeviceType(ports);
      expect(result, equals('Linux Server'));
    });

    test('infers Server from SSH + multiple services', () {
      final ports = [OpenPort(22), OpenPort(80), OpenPort(443)];
      final result = scanner.testInferDeviceType(ports);
      expect(result, equals('Server'));
    });

    test('infers IoT Device from single HTTP port', () {
      final ports = [OpenPort(80)];
      final result = scanner.testInferDeviceType(ports);
      expect(result, equals('IoT Device'));
    });

    test('infers Linux/Unix Device from single SSH port', () {
      final ports = [OpenPort(22)];
      final result = scanner.testInferDeviceType(ports);
      expect(result, equals('Linux/Unix Device'));
    });

    test('infers Web Device from HTTP + HTTPS ports', () {
      final ports = [OpenPort(80), OpenPort(443)];
      final result = scanner.testInferDeviceType(ports);
      expect(result, equals('Web Device'));
    });

    test('infers Remote Display from single VNC port', () {
      final ports = [OpenPort(5900)];
      final result = scanner.testInferDeviceType(ports);
      expect(result, equals('Remote Display'));
    });

    test('returns Unknown Device for unrecognized pattern', () {
      final ports = [OpenPort(23), OpenPort(22)];
      final result = scanner.testInferDeviceType(ports);
      expect(result, equals('Unknown Device'));
    });
  });
}
