// dart

import 'dart:io';

import 'package:network_tools/src/device_info/arp_table_helper.dart';
import 'package:path/path.dart' as p;
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
      '192.168.1.2           02-11-22-33-44-66     static',
      '192.168.1.255         ff-ff-ff-ff-ff-ff     static',
      '192.168.1.3           aa-bb-cc-dd-ee-ff     dynamic',
    ];
  }
}

/// Simulates a localized Windows ARP output where the header cannot be
/// filtered by its English text.
class LocalizedArpTableHelper extends ARPTableHelper {
  LocalizedArpTableHelper() {
    isMobilePlatform = false;
    isMacOSPlatform = false;
    isLinuxPlatform = false;
  }

  @override
  List<String> executeARPCommand() {
    return [
      '接口: 192.168.1.10 --- 0x6',
      'Internet 地址         物理地址              类型',
      'garbage garbage garbage',
      '192.168.1.1           00-11-22-33-44-55     dynamic',
    ];
  }
}

/// Feeds canned numeric output to the parser without touching the OS.
class NumericArpTableHelper extends ARPTableHelper {
  NumericArpTableHelper(
    this.entries, {
    bool macos = false,
    bool linux = false,
    bool mobile = false,
  }) {
    isMacOSPlatform = macos;
    isLinuxPlatform = linux;
    isMobilePlatform = mobile;
  }

  final List<String> entries;

  @override
  List<String> executeNumericARPCommand() => entries;
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
      expect(result[1].macAddress, '02-11-22-33-44-66');
      expect(result[1].interfaceType, 'static');
      expect(result[2].iPAddress, '192.168.1.3');
    });

    test('Ignores localized headers and malformed rows', () async {
      final result = await LocalizedArpTableHelper().buildTable();
      expect(result.length, 1);
      expect(result.first.iPAddress, '192.168.1.1');
      expect(result.first.macAddress, '00-11-22-33-44-55');
    });

    test('ARPTableHelper return non empty result on any machine', () {
      final result = ARPTableHelper().executeARPCommand();
      expect(result, isNotEmpty);
    });
  });

  group('numeric ARP table', () {
    test('is supported on desktop platforms only', () {
      expect(ARPTableHelper().isARPSupported, isTrue);
      final mobile = NumericArpTableHelper(const [], mobile: true);
      expect(mobile.isARPSupported, isFalse);
    });

    test('parses macOS numeric rows without a host name', () async {
      final helper = NumericArpTableHelper(const [
        '? (192.168.29.1) at a8:88:1f:fd:6b:48 on en0 ifscope [ethernet]',
        '? (192.168.29.2) at d6:68:8b:9:0:7 on en0 ifscope [ethernet]',
        '? (192.168.29.3) at (incomplete) on en0 ifscope [ethernet]',
      ], macos: true);

      final result = await helper.buildNumericTable();

      expect(result, hasLength(2));
      expect(result.first.hostname, isEmpty);
      expect(result.first.macAddress, 'a8:88:1f:fd:6b:48');
      // macOS prints octets without leading zeroes.
      expect(result.last.macAddress, 'd6:68:8b:09:00:07');
    });

    test('parses Linux numeric rows without a host name', () async {
      final helper = NumericArpTableHelper(const [
        '? (192.168.1.1) at 00:11:22:33:44:55 [ether] on eth0',
        '? (192.168.1.2) at (incomplete) [ether] on eth0',
      ], linux: true);

      final result = await helper.buildNumericTable();

      expect(result, hasLength(1));
      expect(result.first.hostname, isEmpty);
      expect(result.first.macAddress, '00:11:22:33:44:55');
      expect(result.first.interfaceName, 'eth0');
    });

    test('keeps the Windows separator and skips invalid MACs', () async {
      final helper = NumericArpTableHelper(const [
        '192.168.1.1           00-11-22-33-44-55     dynamic',
        '192.168.1.2           zz-zz-zz-zz-zz-zz     dynamic',
      ]);

      final result = await helper.buildNumericTable();

      expect(result, hasLength(1));
      expect(result.first.macAddress, '00-11-22-33-44-55');
    });

    test('returns no rows on mobile platforms', () async {
      final helper = NumericArpTableHelper(const [
        '? (192.168.1.1) at aa:bb:cc:dd:ee:ff on en0 [ethernet]',
      ], mobile: true);

      expect(await helper.buildNumericTable(), isEmpty);
    });

    test('returns no rows for empty numeric output', () async {
      expect(
        await NumericArpTableHelper(const [], macos: true).buildNumericTable(),
        isEmpty,
      );
    });

    test('skips broadcast, multicast and all-zero MAC rows', () async {
      final helper = NumericArpTableHelper(const [
        '192.168.1.15          ff-ff-ff-ff-ff-ff     static',
        '224.0.0.1             01-00-5e-00-00-01     static',
        '192.168.1.16          00-00-00-00-00-00     static',
        '192.168.1.17          00-11-22-33-44-55     dynamic',
      ]);

      final result = await helper.buildNumericTable();

      expect(result, hasLength(1));
      expect(result.single.iPAddress, '192.168.1.17');
    });
  });

  group('platform fallbacks', () {
    ProcessResult processResult(String stdout, {int exitCode = 0}) =>
        ProcessResult(0, exitCode, stdout, '');

    test('base commands return nothing on mobile', () {
      final helper = ARPTableHelper()..isMobilePlatform = true;

      expect(helper.executeARPCommand(), isEmpty);
      expect(helper.executeNumericARPCommand(), isEmpty);
    });

    test('legacy command survives a failing exit code', () async {
      final helper = ARPTableHelper(
        runArp: (_) => processResult('', exitCode: 1),
      );

      expect(await helper.buildTable(), isEmpty);
    });

    test('legacy command survives a missing arp binary', () async {
      final helper = ARPTableHelper(
        runArp: (_) => throw const ProcessException('arp', []),
      );

      expect(await helper.buildTable(), isEmpty);
    });

    test('legacy command survives unexpected errors', () async {
      final helper = ARPTableHelper(runArp: (_) => throw StateError('boom'));

      expect(await helper.buildTable(), isEmpty);
    });

    test('numeric command survives a failing exit code', () async {
      final helper =
          ARPTableHelper(runArp: (_) => processResult('', exitCode: 2))
            ..isMacOSPlatform = true
            ..isLinuxPlatform = false;

      expect(await helper.buildNumericTable(), isEmpty);
    });

    test('numeric command survives a missing arp binary', () async {
      final helper =
          ARPTableHelper(runArp: (_) => throw const ProcessException('arp', []))
            ..isMacOSPlatform = true
            ..isLinuxPlatform = false;

      expect(await helper.buildNumericTable(), isEmpty);
    });

    test('numeric command survives unexpected errors', () async {
      final helper = ARPTableHelper(runArp: (_) => throw StateError('boom'))
        ..isMacOSPlatform = true
        ..isLinuxPlatform = false;

      expect(await helper.buildNumericTable(), isEmpty);
    });

    test('reads the Linux proc table directly', () async {
      final Directory dir = await Directory.systemTemp.createTemp('arp_proc_');
      addTearDown(() => dir.delete(recursive: true));
      final File file = File(p.join(dir.path, 'arp'))
        ..writeAsStringSync('''
IP address       HW type     Flags       HW address            Mask     Device
192.168.1.1      0x1         0x2         00:11:22:33:44:55     *        eth0
192.168.1.2      0x1         0x0         aa:bb:cc:dd:ee:ff     *        eth0
192.168.1.3      0x1         0x2
192.168.1.4      0x1         0xzz        11:22:33:44:55:66     *        eth0
''');
      final helper =
          ARPTableHelper(
              linuxArpPath: file.path,
              runArp: (_) => throw StateError('the arp binary must not run'),
            )
            ..isMacOSPlatform = false
            ..isLinuxPlatform = true;

      final result = await helper.buildNumericTable();

      expect(result, hasLength(1));
      expect(result.single.iPAddress, '192.168.1.1');
      expect(result.single.macAddress, '00:11:22:33:44:55');
      expect(result.single.interfaceName, 'eth0');
    });

    test('falls back to the binary when the proc table is missing', () async {
      final capturedArguments = <List<String>>[];
      final helper =
          ARPTableHelper(
              linuxArpPath: p.join(Directory.systemTemp.path, 'nt-missing-arp'),
              runArp: (arguments) {
                capturedArguments.add(arguments);
                return processResult(
                  '? (192.168.1.1) at aa:bb:cc:dd:ee:ff [ether] on eth0',
                );
              },
            )
            ..isMacOSPlatform = false
            ..isLinuxPlatform = true;

      final result = await helper.buildNumericTable();

      expect(result.single.iPAddress, '192.168.1.1');
      expect(capturedArguments.single, ['-an']);
    });

    test('falls back to the binary when the proc read fails', () async {
      final Directory dir = await Directory.systemTemp.createTemp('arp_dir_');
      addTearDown(() => dir.delete(recursive: true));
      final helper =
          ARPTableHelper(
              // A directory makes readAsLinesSync throw.
              linuxArpPath: dir.path,
              runArp: (_) => processResult(''),
            )
            ..isMacOSPlatform = false
            ..isLinuxPlatform = true;

      expect(await helper.buildNumericTable(), isEmpty);
    });
  });

  group('ARPCache', () {
    test('priming is a no-op on mobile platforms', () async {
      final helper = NumericArpTableHelper(const [], mobile: true);
      await helper.primeARPCache(const ['192.168.1.1']);
    });

    test('priming is a no-op for an empty host list', () async {
      await ARPTableHelper().primeARPCache(const []);
    });

    test('priming probes desktop hosts and settles', () async {
      await ARPTableHelper().primeARPCache(const [
        '127.0.0.1',
      ], settleDelay: Duration.zero);
    });
  });
}
