import 'package:dart_ping/dart_ping.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/injection.dart';
import 'package:network_tools/src/repository/repository.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

class _FakeRepository<T> implements Repository<T> {
  _FakeRepository(this.value);

  T? value;

  @override
  Future<void> build() async {}

  @override
  Future<bool> clear() async => true;

  @override
  Future<void> close() async {}

  @override
  Future<List<String?>?> entries() async => const [];

  @override
  Future<T?> entryFor(String address) async => value;
}

ARPData arpData({
  String hostname = 'arp-host',
  String mac = 'aa:bb:cc:dd:ee:ff',
}) {
  return ARPData(
    hostname: hostname,
    iPAddress: '192.0.2.1',
    macAddress: mac,
    interfaceName: 'en0',
    interfaceType: 'ether',
    createdAt: DateTime.now(),
  );
}

MdnsInfo mdnsInfo() {
  return MdnsInfo(
    srvResourceRecord: const SrvResourceRecord(
      'device._ipp._tcp.local',
      0,
      target: 'device.local',
      port: 631,
      priority: 0,
      weight: 0,
    ),
    ptrResourceRecord: const PtrResourceRecord(
      '_ipp._tcp.local',
      0,
      domainName: 'local',
    ),
    txtResourceRecord: const TxtResourceRecord(
      'device._ipp._tcp.local',
      0,
      text: 'rp=printers/device',
    ),
  );
}

void main() {
  late _FakeRepository<ARPData> arpRepository;
  late _FakeRepository<Vendor> vendorRepository;

  setUp(() async {
    await getIt.reset();
    arpRepository = _FakeRepository<ARPData>(null);
    vendorRepository = _FakeRepository<Vendor>(null);
    getIt.registerSingleton<Repository<ARPData>>(arpRepository);
    getIt.registerSingleton<Repository<Vendor>>(vendorRepository);
  });

  group('ActiveHost construction', () {
    test('parses IPv4 hostId and exposes address', () {
      final host = ActiveHost.buildWithAddress(
        address: '192.168.1.42',
        macAddress: 'aa:bb:cc:dd:ee:ff',
        openPorts: [OpenPort(80)],
      );

      expect(host.address, '192.168.1.42');
      expect(host.hostId, '42');
      expect(host.openPorts.single.port, 80);
      expect(host.weirdHostName, '192.168.1.42');
    });

    test('parses IPv6 hostId', () {
      final host = ActiveHost.buildWithAddress(address: '::1');

      expect(host.hostId, '1');
    });

    test('buildWithAddress throws for an invalid address', () {
      expect(
        () => ActiveHost.buildWithAddress(address: 'not-an-address'),
        throwsA(isA<String>()),
      );
    });

    test('fromSendableActiveHost throws for an invalid address', () {
      expect(
        () => ActiveHost.fromSendableActiveHost(
          sendableActiveHost: SendableActiveHost('not-an-address'),
        ),
        throwsA(isA<String>()),
      );
    });

    test('fromSendableActiveHost copies the sendable host data', () async {
      const pingData = PingResponse(
        seq: 1,
        ttl: 64,
        time: Duration(milliseconds: 12),
        ip: '192.168.1.42',
      );
      final host = ActiveHost.fromSendableActiveHost(
        sendableActiveHost: SendableActiveHost(
          '192.168.1.42',
          pingData: pingData,
          openPorts: [OpenPort(22)],
        ),
        macAddress: 'aa:bb:cc:dd:ee:ff',
      );

      expect(host.address, '192.168.1.42');
      expect(host.pingData, pingData);
      expect(host.openPorts.single.port, 22);
      expect(host.responseTime, const Duration(milliseconds: 12));
      expect(await host.getMacAddress(), 'aa:bb:cc:dd:ee:ff');
    });

    test('exposes the mdns info passed at construction', () async {
      final info = mdnsInfo();
      final host = ActiveHost.buildWithAddress(
        address: '192.0.2.1',
        mdnsInfo: info,
      );

      expect(await host.mdnsInfo, same(info));
    });

    test('responseTime is null without ping data', () {
      final host = ActiveHost.buildWithAddress(address: '192.168.1.42');

      expect(host.responseTime, isNull);
      expect(host.pingData, isNull);
    });
  });

  group('ActiveHost lazy resolution', () {
    test('hostName is resolved once and cached', () async {
      final host = ActiveHost.buildWithAddress(address: '127.0.0.1');

      final name = await host.hostName;
      expect(name, isNotNull);
      expect(await host.hostName, name);
    });

    test('setHostInfo handles addresses without a PTR record', () async {
      final host = ActiveHost.buildWithAddress(address: '192.0.2.1');

      await expectLater(host.setHostInfo(), completes);
    });

    test('arpData and vendor come from the registered repositories', () async {
      arpRepository.value = arpData();
      vendorRepository.value = Vendor(
        macPrefix: 'AABBCC',
        vendorName: 'Test Vendor',
        private: 'false',
        blockType: 'MA-L',
        lastUpdate: '2024-01-01',
      );
      final host = ActiveHost.buildWithAddress(address: '192.0.2.1');

      expect((await host.arpData)?.hostname, 'arp-host');
      expect((await host.vendor)?.vendorName, 'Test Vendor');
      expect(await host.getMacAddress(), 'aa:bb:cc:dd:ee:ff');
    });

    test('vendor is null when no MAC address is available', () async {
      final host = ActiveHost.buildWithAddress(address: '192.0.2.1');

      expect(await host.getMacAddress(), isNull);
      expect(await host.vendor, isNull);
    });

    test('resolveInfo resolves every detail', () async {
      arpRepository.value = arpData();
      final host = ActiveHost.buildWithAddress(address: '127.0.0.1');

      await expectLater(host.resolveInfo(), completes);
    });

    test('getPingData does not throw', () {
      expect(
        ActiveHost.getPingData('127.0.0.1'),
        anyOf(isNull, isA<PingResponse>()),
      );
    });
  });

  group('ActiveHost deviceName', () {
    test('prefers the host name', () async {
      final host = ActiveHost.buildWithAddress(address: '127.0.0.1');

      final name = await host.deviceName;
      expect(name, isNot(ActiveHost.generic));
      expect(name, isNotEmpty);
    });

    test('falls back to the mDNS name', () async {
      final host = ActiveHost.buildWithAddress(
        address: '192.0.2.1',
        mdnsInfo: mdnsInfo(),
      );

      expect(await host.deviceName, 'device');
    });

    test('falls back to the ARP host name', () async {
      arpRepository.value = arpData();
      final host = ActiveHost.buildWithAddress(address: '192.0.2.1');

      expect(await host.deviceName, 'arp-host');
    });

    test('falls back to the generic name', () async {
      final host = ActiveHost.buildWithAddress(address: '192.0.2.1');

      expect(await host.deviceName, ActiveHost.generic);
    });

    test('ignores useless host names', () async {
      arpRepository.value = arpData(hostname: '?');
      final host = ActiveHost.buildWithAddress(address: '192.0.2.1');

      expect(await host.deviceName, ActiveHost.generic);
    });
  });

  group('ActiveHost formatting and equality', () {
    test('compareTo orders by hostId', () {
      final first = ActiveHost.buildWithAddress(address: '192.168.1.2');
      final second = ActiveHost.buildWithAddress(address: '192.168.1.3');

      expect(first.compareTo(second), lessThan(0));
      expect(second.compareTo(first), greaterThan(0));
    });

    test('equality and hashCode are based on the address', () {
      final first = ActiveHost.buildWithAddress(address: '192.168.1.2');
      final second = ActiveHost.buildWithAddress(
        address: '192.168.1.2',
        macAddress: 'aa:bb:cc:dd:ee:ff',
      );
      final other = ActiveHost.buildWithAddress(address: '192.168.1.3');

      expect(first, equals(second));
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(equals(other)));
      expect(first, isNot(equals('192.168.1.2')));
    });

    test('toString includes the host details', () {
      final host = ActiveHost(
        internetAddress: InternetAddress('192.168.1.42'),
        pingData: const PingResponse(time: Duration(milliseconds: 12)),
        openPorts: [OpenPort(80)],
      );

      final string = host.toString();
      expect(string, contains('Address: 192.168.1.42'));
      expect(string, contains('HostId: 42'));
      expect(string, contains('Time: 12ms'));
      expect(string, contains('port: 80'));
    });

    test('toStringFull includes resolved details', () async {
      arpRepository.value = arpData();
      vendorRepository.value = Vendor(
        macPrefix: 'AABBCC',
        vendorName: 'Test Vendor',
        private: 'false',
        blockType: 'MA-L',
        lastUpdate: '2024-01-01',
      );
      final host = ActiveHost.buildWithAddress(address: '127.0.0.1');

      final string = await host.toStringFull();
      expect(string, contains('MAC: aa:bb:cc:dd:ee:ff'));
      expect(string, contains('Vendor: Test Vendor'));
      expect(string, contains('DeviceName:'));
    });
  });
}
