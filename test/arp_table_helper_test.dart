// dart

import 'package:network_tools/src/device_info/arp_table_helper.dart';
import 'package:test/test.dart';

class MockArpTableHelper extends ARPTableHelper {
  void setPlatform({
    bool android = false,
    bool ios = false,
    bool linux = false,
    bool macos = false,
  }) {
    super.isMobilePlatform = android || ios;
    super.isMacOSPlatform = macos;
    super.isLinuxPlatform = linux;
  }

  @override
  List<String> executeARPCommand() {
    if (super.isMobilePlatform) {
      return [];
    } else if (super.isMacOSPlatform) {
      return [
        '? (169.254.169.254) at (incomplete) on en0 [ethernet]',
        'reliance.reliance (192.168.29.1) at a8:88:1f:fd:6b:48 on en0 ifscope [ethernet]',
        '? (192.168.29.99) at 72:36:33:cd:33:13 on en0 ifscope [ethernet]',
        '? (192.168.29.188) at 3a:59:30:c3:64:ba on en0 ifscope permanent [ethernet]',
      ];
    } else if (super.isLinuxPlatform) {
      return [
        'router (192.168.1.1) at 00:11:22:33:44:55 [ether] on eth0',
        'host2 (192.168.1.2) at (incomplete) [ether] on eth0',
        'my-pc (192.168.1.3) at aa:bb:cc:dd:ee:ff [ether] on eth0',
      ];
    }
    return [
      'Interface: 192.168.1.10 --- 0x6',
      'Internet Address      Physical Address      Type',
      '192.168.1.1           00-11-22-33-44-55     dynamic',
      '192.168.1.2           ff-ff-ff-ff-ff-ff     static',
      '192.168.1.3           aa-bb-cc-dd-ee-ff     dynamic',
    ];
  }
}

void main() {
  final mockArpTableHelper = MockArpTableHelper();
  group('ARPTableHelper', () {
    test('Returns empty list on Android', () async {
      mockArpTableHelper.setPlatform(android: true);
      final result = await mockArpTableHelper.buildTable();
      expect(result, isEmpty);
    });

    test('Returns empty list on iOS', () async {
      mockArpTableHelper.setPlatform(ios: true);
      final result = await mockArpTableHelper.buildTable();
      expect(result, isEmpty);
    });

    test('Parses Linux ARP output', () async {
      mockArpTableHelper.setPlatform(linux: true);
      final result = await mockArpTableHelper.buildTable();
      expect(result.length, 2);
      final arp = result.first;
      expect(arp.hostname, 'router');
      expect(arp.iPAddress, '192.168.1.1');
      expect(arp.macAddress, '00:11:22:33:44:55');
      expect(arp.interfaceName, 'eth0');
      expect(arp.interfaceType, 'ether');
    });

    //TODO: fix me
    test('Parses macOS ARP output', () async {
      mockArpTableHelper.setPlatform(macos: true);
      final result = await mockArpTableHelper.buildTable();
      expect(result.length, 3);
      final arp = result.first;
      expect(arp.hostname, 'reliance.reliance');
      expect(arp.iPAddress, '192.168.29.1');
      expect(arp.macAddress, 'a8:88:1f:fd:6b:48');
      expect(arp.interfaceName, 'en0');
      expect(arp.interfaceType, 'ethernet');
    });

    test('Parses Windows ARP output', () async {
      mockArpTableHelper.setPlatform(
        // ignore: avoid_redundant_argument_values
        android: false,
        // ignore: avoid_redundant_argument_values
        ios: false,
        // ignore: avoid_redundant_argument_values
        linux: false,
        // ignore: avoid_redundant_argument_values
        macos: false,
      );
      final result = await mockArpTableHelper.buildTable();
      expect(result.length, 3);
      expect(result[0].iPAddress, '192.168.1.1');
      expect(result[0].macAddress, '00-11-22-33-44-55');
      expect(result[0].interfaceType, 'dynamic');
      expect(result[1].iPAddress, '192.168.1.2');
      expect(result[1].macAddress, 'ff-ff-ff-ff-ff-ff');
      expect(result[1].interfaceType, 'static');
    });

    test('ARPTableHelper return non empty result on any machine', () {
      final result = ARPTableHelper().executeARPCommand();
      expect(result, isNotEmpty);
    });
  });
}
