import 'package:network_tools/network_tools.dart';
import 'package:test/test.dart';

void main() {
  test('Testing Host Scanner', () {
    expect(HostScanner.getMaxHost("10.0.0.0"), HostScanner.classASubnets);
    expect(HostScanner.getMaxHost("164.0.0.0"), HostScanner.classBSubnets);
    expect(HostScanner.getMaxHost("200.0.0.0"), HostScanner.classCSubnets);
  });
}
