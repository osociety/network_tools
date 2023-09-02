import 'package:network_tools/network_tools.dart';
import 'package:test/test.dart';

void main() {
  group("Running mdns scanner group", () {
    test('Running searchMdnsDevices tests', () async {
      final mdnsDevices = await MdnsScanner.searchMdnsDevices();
      expectLater(
        mdnsDevices,
        isA<List<ActiveHost>>(),
      );
    });
  });
}
