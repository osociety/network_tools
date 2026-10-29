import 'dart:io';

import 'package:network_tools/network_tools.dart';
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
