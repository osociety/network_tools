import 'package:network_tools/network_tools.dart';
import 'package:test/test.dart';

void main() {
  group("Running mdns scanner group", () {
    test('Running searchMdnsDevices tests', () {
      expectLater(
        MdnsScanner.searchMdnsDevices(),
        completion(
          isA<List<ActiveHost>>(),
        ),
      );
    });
  });
}
