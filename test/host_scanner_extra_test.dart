import 'dart:io';

import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/device_info/arp_table_helper.dart';
import 'package:network_tools/src/device_info/vendor_table.dart';
import 'package:network_tools/src/injection.dart';
import 'package:network_tools/src/repository/repository.dart';
import 'package:network_tools/src/services/impls/host_scanner_service_impl.dart';
import 'package:network_tools/src/services/impls/port_scanner_service_impl.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class _FakeARPRepository implements Repository<ARPData> {
  _FakeARPRepository(this.value);

  ARPData? value;

  @override
  Future<void> build() async {}

  @override
  Future<bool> clear() async => true;

  @override
  Future<void> close() async {}

  @override
  Future<List<String?>?> entries() async => const [];

  @override
  Future<ARPData?> entryFor(String address) async => value;
}

class _ThrowingARPRepository extends _FakeARPRepository {
  _ThrowingARPRepository() : super(null);

  @override
  Future<ARPData?> entryFor(String address) =>
      throw StateError('arp lookup failed');
}

class _FakeARPTableHelper extends ARPTableHelper {
  _FakeARPTableHelper(this.entries, {this.supported = true}) {
    isMobilePlatform = !supported;
    isMacOSPlatform = false;
    isLinuxPlatform = false;
  }

  final List<ARPData> entries;
  final bool supported;
  int primeCount = 0;

  @override
  bool get isARPSupported => supported;

  @override
  Future<void> primeARPCache(
    Iterable<String> hosts, {
    Duration settleDelay = ARPTableHelper.defaultPrimingDelay,
    int port = 9,
  }) async {
    primeCount++;
  }

  @override
  Future<List<ARPData>> buildNumericTable() async => entries;
}

class _ThrowingARPTableHelper extends _FakeARPTableHelper {
  _ThrowingARPTableHelper() : super(const <ARPData>[]);

  @override
  Future<List<ARPData>> buildNumericTable() async =>
      throw StateError('neighbor table unavailable');
}

ARPData _arpEntry(String address, {String mac = 'aa:bb:cc:dd:ee:ff'}) {
  return ARPData(
    hostname: '',
    iPAddress: address,
    macAddress: mac,
    interfaceName: 'en0',
    interfaceType: 'ether',
    createdAt: DateTime.now(),
  );
}

void main() {
  final HostScannerServiceImpl hostScanner = HostScannerServiceImpl();

  setUp(() async {
    PortScannerServiceImpl();
    await getIt.reset();
    getIt.registerSingleton<Repository<ARPData>>(_FakeARPRepository(null));
  });

  group('getMaxHost', () {
    test('returns the class A subnet count', () {
      expect(hostScanner.getMaxHost('10.0.0'), hostScanner.classASubnets);
    });

    test('returns the class B subnet count', () {
      expect(hostScanner.getMaxHost('150.0.0'), hostScanner.classBSubnets);
    });

    test('returns the class C subnet count', () {
      expect(hostScanner.getMaxHost('192.168.1'), hostScanner.classCSubnets);
    });

    test('throws for an empty subnet', () {
      expect(() => hostScanner.getMaxHost(''), throwsArgumentError);
    });

    test('throws for an out of range first octet', () {
      expect(() => hostScanner.getMaxHost('224.0.0'), throwsRangeError);
    });
  });

  group('validateAndGetLastValidSubnet', () {
    test('returns the last host id when it is valid', () {
      expect(hostScanner.validateAndGetLastValidSubnet('127.0.0', 1, 10), 10);
    });

    test('throws when the first host id is greater than the last', () {
      expect(
        () => hostScanner.validateAndGetLastValidSubnet('127.0.0', 20, 10),
        throwsA(isA<String>()),
      );
    });

    test('throws when the host ids are out of range', () {
      expect(
        () => hostScanner.validateAndGetLastValidSubnet('127.0.0', 0, 10),
        throwsA(isA<String>()),
      );
      expect(
        () => hostScanner.validateAndGetLastValidSubnet('127.0.0', 1, 1000),
        throwsA(isA<String>()),
      );
    });
  });

  group('getAllSendablePingableDevices', () {
    test('yields pingable hosts in ascending order', () async {
      final progress = <double>[];
      final hosts = await hostScanner
          .getAllSendablePingableDevices(
            '127.0.0',
            hostIds: [1],
            progressCallback: progress.add,
          )
          .toList();

      expect(hosts.map((h) => h.address), contains('127.0.0.1'));
      expect(progress, isNotEmpty);
    });

    test('yields pingable hosts in unordered mode', () async {
      final hosts = await hostScanner
          .getAllSendablePingableDevices(
            '127.0.0',
            hostIds: [1],
            resultsInAddressAscendingOrder: false,
          )
          .toList();

      expect(hosts.map((h) => h.address), contains('127.0.0.1'));
    });

    test('getAllPingableDevices wraps sendable hosts', () async {
      final hosts = await hostScanner
          .getAllPingableDevices('127.0.0', hostIds: [1])
          .toList();

      expect(hosts.map((h) => h.address), contains('127.0.0.1'));
    });

    test('falls back to the ARP repository for non pingable hosts', () async {
      final arpRepository = _FakeARPRepository(
        ARPData(
          hostname: 'arp-host',
          iPAddress: '203.0.113.1',
          macAddress: 'aa:bb:cc:dd:ee:ff',
          interfaceName: 'en0',
          interfaceType: 'ether',
          createdAt: DateTime.now(),
        ),
      );
      getIt.unregister<Repository<ARPData>>();
      getIt.registerSingleton<Repository<ARPData>>(arpRepository);

      final hosts = await hostScanner
          .getAllSendablePingableDevices('203.0.113', hostIds: [1])
          .toList();

      expect(hosts.map((h) => h.address), contains('203.0.113.1'));
    });

    test('does not yield hosts without a ping or ARP entry', () async {
      final hosts = await hostScanner
          .getAllSendablePingableDevices('203.0.113', hostIds: [2])
          .toList();

      expect(hosts, isEmpty);
    });

    test('survives ARP repository failures', () async {
      getIt.unregister<Repository<ARPData>>();
      getIt.registerSingleton<Repository<ARPData>>(_ThrowingARPRepository());

      final hosts = await hostScanner
          .getAllSendablePingableDevices('203.0.113', hostIds: [3])
          .toList();

      expect(hosts, isEmpty);
    });
  });

  group('ARP-first discovery', () {
    HostScannerServiceImpl scannerWith(
      ARPTableHelper helper, {
      bool localSubnet = true,
    }) {
      return HostScannerServiceImpl(
        arpTableHelper: helper,
        isLocalSubnet: (_) async => localSubnet,
      );
    }

    test('yields neighbor table hosts in ascending order', () async {
      final helper = _FakeARPTableHelper([
        _arpEntry('127.0.0.1'),
        _arpEntry('127.0.0.3', mac: '11:22:33:44:55:66'),
      ]);
      final progress = <double>[];
      final hosts = await scannerWith(helper)
          .getAllSendablePingableDevices(
            '127.0.0',
            lastHostId: 4,
            progressCallback: progress.add,
          )
          .toList();

      expect(hosts.map((h) => h.address), ['127.0.0.1', '127.0.0.3']);
      expect(hosts.first.macAddress, 'aa:bb:cc:dd:ee:ff');
      expect(hosts.last.macAddress, '11:22:33:44:55:66');
      expect(helper.primeCount, 1);
      expect(progress.last, 100);
    });

    test('yields neighbor table hosts in unordered mode', () async {
      final helper = _FakeARPTableHelper([_arpEntry('127.0.0.1')]);
      final hosts = await scannerWith(helper)
          .getAllSendablePingableDevices(
            '127.0.0',
            hostIds: [1],
            resultsInAddressAscendingOrder: false,
          )
          .toList();

      expect(hosts.single.address, '127.0.0.1');
      expect(hosts.single.macAddress, 'aa:bb:cc:dd:ee:ff');
      expect(helper.primeCount, 1);
    });

    test('keeps neighbor table hosts that ignore ICMP', () async {
      final helper = _FakeARPTableHelper([_arpEntry('192.0.2.1')]);
      final hosts = await scannerWith(
        helper,
      ).getAllSendablePingableDevices('192.0.2', hostIds: [1]).toList();

      expect(hosts.single.address, '192.0.2.1');
      expect(hosts.single.pingData, isNull);
      expect(hosts.single.macAddress, 'aa:bb:cc:dd:ee:ff');
    });

    test('ignores neighbor table entries outside the requested ids', () async {
      final helper = _FakeARPTableHelper([_arpEntry('192.0.2.99')]);
      final progress = <double>[];
      final hosts = await scannerWith(helper)
          .getAllSendablePingableDevices(
            '192.0.2',
            hostIds: [1],
            progressCallback: progress.add,
          )
          .toList();

      expect(hosts, isEmpty);
      expect(progress, isEmpty);
    });

    test('adds the scanning machine when it is inside the range', () async {
      // Reproduces CI: the neighbor table holds other hosts, but none of the
      // requested ids, and the local address is absent from the table.
      final helper = _FakeARPTableHelper([_arpEntry('127.0.0.99')]);
      final hosts = await scannerWith(helper)
          .getAllSendablePingableDevices(
            '127.0.0',
            hostIds: [1],
            timeoutInSeconds: 3,
          )
          .toList();

      expect(hosts.single.address, '127.0.0.1');
      expect(hosts.single.pingData, isNotNull);
    });

    test('reports full progress for a single-host range', () async {
      final helper = _FakeARPTableHelper([_arpEntry('127.0.0.1')]);
      final progress = <double>[];
      await scannerWith(helper)
          .getAllSendablePingableDevices(
            '127.0.0',
            lastHostId: 1,
            progressCallback: progress.add,
          )
          .toList();

      expect(progress, isNotEmpty);
      expect(progress.every((value) => value == 100), isTrue);
    });

    test('falls back to pinging when the neighbor table is empty', () async {
      final helper = _FakeARPTableHelper(const <ARPData>[]);
      final hosts = await scannerWith(
        helper,
      ).getAllSendablePingableDevices('127.0.0', hostIds: [1]).toList();

      expect(hosts.single.address, '127.0.0.1');
      expect(hosts.single.pingData, isNotNull);
      expect(helper.primeCount, 1);
    });

    test('falls back to pinging when the neighbor table read fails', () async {
      final helper = _ThrowingARPTableHelper();
      final hosts = await scannerWith(
        helper,
      ).getAllSendablePingableDevices('127.0.0', hostIds: [1]).toList();

      expect(hosts.single.address, '127.0.0.1');
      expect(hosts.single.pingData, isNotNull);
    });

    test('uses the ping sweep when ARP is unsupported', () async {
      final helper = _FakeARPTableHelper([
        _arpEntry('127.0.0.1'),
      ], supported: false);
      final hosts = await scannerWith(
        helper,
      ).getAllSendablePingableDevices('127.0.0', hostIds: [1]).toList();

      expect(hosts.single.address, '127.0.0.1');
      expect(helper.primeCount, 0);
    });

    test('uses the ping sweep when the subnet is not local', () async {
      final helper = _FakeARPTableHelper([_arpEntry('127.0.0.1')]);
      final hosts = await scannerWith(
        helper,
        localSubnet: false,
      ).getAllSendablePingableDevices('127.0.0', hostIds: [1]).toList();

      expect(hosts.single.address, '127.0.0.1');
      expect(helper.primeCount, 0);
    });

    test(
      'getAllPingableDevices exposes the neighbor table MAC address',
      () async {
        final helper = _FakeARPTableHelper([
          _arpEntry('127.0.0.1', mac: 'de:ad:be:ef:00:01'),
        ]);
        final hosts = await scannerWith(
          helper,
        ).getAllPingableDevices('127.0.0', hostIds: [1]).toList();

        expect(await hosts.single.getMacAddress(), 'de:ad:be:ef:00:01');
      },
    );
  });

  group('getAllPingableDevicesAsync', () {
    test('reports progress while scanning in an isolate', () async {
      final tempDirectory = await Directory.systemTemp.createTemp('nt_async_');
      File(
        p.join(tempDirectory.path, VendorTable.fileName),
      ).writeAsStringSync('mac,vendor\nAABBCC,Test Vendor\n');
      dbDirectory = tempDirectory.path;
      enableDebugging = false;

      try {
        final progress = <double>[];
        final hosts = await hostScanner
            .getAllPingableDevicesAsync(
              '127.0.0',
              hostIds: [1],
              progressCallback: progress.add,
            )
            .toList();

        expect(hosts.map((h) => h.address), contains('127.0.0.1'));
        expect(progress, isNotEmpty);
        expect(progress.last, 100);
      } finally {
        await _deleteTempDirectory(tempDirectory);
      }
    });
  });

  group('scanDevicesForSinglePort', () {
    late ServerSocket server;

    setUp(() async {
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    });

    tearDown(() async {
      await server.close();
    });

    test('finds hosts with the port open in ascending order', () async {
      final progress = <double>[];
      final hosts = await hostScanner
          .scanDevicesForSinglePort(
            '127.0.0',
            server.port,
            lastHostId: 1,
            progressCallback: progress.add,
          )
          .toList();

      expect(hosts.single.address, '127.0.0.1');
      expect(hosts.single.openPorts.map((p) => p.port), contains(server.port));
      expect(progress, isNotEmpty);
    });

    test('finds hosts with the port open in unordered mode', () async {
      final hosts = await hostScanner
          .scanDevicesForSinglePort(
            '127.0.0',
            server.port,
            lastHostId: 1,
            resultsInAddressAscendingOrder: false,
          )
          .toList();

      expect(hosts.single.address, '127.0.0.1');
    });

    test('returns no hosts for a closed port', () async {
      final hosts = await hostScanner
          .scanDevicesForSinglePort(
            '127.0.0',
            1,
            lastHostId: 1,
            timeout: const Duration(milliseconds: 200),
          )
          .toList();

      expect(hosts, isEmpty);
    });

    test('throws for an invalid host range', () {
      expect(
        () => hostScanner
            .scanDevicesForSinglePort(
              '127.0.0',
              80,
              firstHostId: 20,
              lastHostId: 10,
            )
            .toList(),
        throwsA(isA<String>()),
      );
    });
  });
}

/// The scan isolate opens the database inside the temporary directory, and
/// Windows keeps that file locked until the killed isolate is fully gone.
Future<void> _deleteTempDirectory(Directory directory) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    try {
      await directory.delete(recursive: true);
      return;
    } on FileSystemException {
      if (attempt == 29) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}
