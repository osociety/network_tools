import 'package:network_tools/src/mdns_scanner/get_srv_list_by_os/srv_list_linux.dart';
import 'package:test/test.dart';

void main() {
  group('SrvListLinux OS command execution', () {
    test('getSrvRecordList returns a list on any platform', () async {
      expect(await SrvListLinux.getSrvRecordList(), isA<List<String>>());
    });

    test('runAvahiBrowseCommand tolerates unavailable tools', () async {
      expect(await SrvListLinux.runAvahiBrowseCommand(), isA<List<String>>());
    });

    test('runMdnsScanCommand tolerates unavailable tools', () async {
      expect(await SrvListLinux.runMdnsScanCommand(), isA<List<String>>());
    });
  });
}
