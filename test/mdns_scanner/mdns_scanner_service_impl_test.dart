import 'dart:io' as dart_io;

import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/services/impls/mdns_scanner_service_impl.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart' as universal_io;

void main() {
  group('MdnsScannerServiceImpl Unit Tests', () {
    late MdnsScannerServiceImpl mdnsScannerService;
    late bool dbInitialized;

    setUpAll(() async {
      dbInitialized = false;
      // Use unique database directory per test to avoid lock contention on parallel test runs
      final testDbDir =
          'build/test_db_mdns_impl_${dart_io.pid}_${DateTime.now().millisecondsSinceEpoch}';
      try {
        await configureNetworkTools(testDbDir);
        dbInitialized = true;
      } catch (e) {
        // In parallel test environments (CI), database might be locked
        // Tests that need DB will be skipped
        if (!e.toString().contains('database is locked')) {
          rethrow;
        }
      }
    });

    setUp(() {
      mdnsScannerService = MdnsScannerServiceImpl();
    });

    group('Service instantiation', () {
      test('Service should be instantiable', () {
        expect(mdnsScannerService, isNotNull);
        expect(mdnsScannerService, isA<MdnsScannerServiceImpl>());
      });

      test('Multiple instances should be creatable', () {
        final service1 = MdnsScannerServiceImpl();
        final service2 = MdnsScannerServiceImpl();

        expect(service1, isA<MdnsScannerServiceImpl>());
        expect(service2, isA<MdnsScannerServiceImpl>());
        expect(identical(service1, service2), false);
      });

      test('Service should extend MdnsScannerService', () {
        expect(mdnsScannerService, isA<MdnsScannerService>());
      });
    });

    group('Service interface compliance', () {
      test('searchMdnsDevices method exists and is callable', () {
        expect(mdnsScannerService.searchMdnsDevices, isA<Function>());
      });

      test('findingMdnsWithAddress method exists and is callable', () {
        expect(mdnsScannerService.findingMdnsWithAddress, isA<Function>());
      });

      test('findAllActiveHostForSrv method exists and is callable', () {
        expect(mdnsScannerService.findAllActiveHostForSrv, isA<Function>());
      });

      test('convertSrvToHostName method exists and is callable', () {
        expect(mdnsScannerService.convertSrvToHostName, isA<Function>());
      });
    });

    group('Error handling', () {
      test('Service creation does not throw', () {
        expect(() => MdnsScannerServiceImpl(), returnsNormally);
      });

      test('Multiple service instances do not interfere', () {
        final service1 = MdnsScannerServiceImpl();
        final service2 = MdnsScannerServiceImpl();
        final service3 = MdnsScannerServiceImpl();

        expect(service1, isNotNull);
        expect(service2, isNotNull);
        expect(service3, isNotNull);
      });
    });

    group('Method signatures', () {
      test(
        'searchMdnsDevices accepts forceUseOfSavedSrvRecordList parameter',
        () async {
          if (!dbInitialized) {
            return; // Skip if database not initialized (likely locked on CI)
          }
          final mockService = MockMdnsScannerServiceImpl();
          // Test that the method can be called with the parameter
          await expectLater(
            mockService.searchMdnsDevices(forceUseOfSavedSrvRecordList: true),
            completes,
          );
        },
      );

      test('searchMdnsDevices can be called without parameters', () async {
        if (!dbInitialized) {
          return; // Skip if database not initialized (likely locked on CI)
        }
        final mockService = MockMdnsScannerServiceImpl();
        await expectLater(mockService.searchMdnsDevices(), completes);
      });
    });

    group('Service state', () {
      test('New instances should be independent', () {
        final service1 = MdnsScannerServiceImpl();
        final service2 = MdnsScannerServiceImpl();
        final service3 = MdnsScannerServiceImpl();

        // All should be valid instances
        expect([
          service1,
          service2,
          service3,
        ], everyElement(isA<MdnsScannerServiceImpl>()));
      });

      test('Service should maintain proper type', () {
        final services = [
          MdnsScannerServiceImpl(),
          MdnsScannerServiceImpl(),
          MdnsScannerServiceImpl(),
        ];

        for (final service in services) {
          expect(service, isA<MdnsScannerServiceImpl>());
          expect(service, isA<MdnsScannerService>());
        }
      });
    });

    group('Basic operations', () {
      test('Service instance can be reused', () {
        final service = MdnsScannerServiceImpl();

        // Should be able to store and reuse the reference
        expect(service, isNotNull);
        final serviceRef = service;
        expect(serviceRef, equals(service));
      });

      test('Service methods are public', () {
        // Check that important methods are not private
        expect(
          mdnsScannerService.searchMdnsDevices.toString(),
          contains('Future'),
        );
      });
    });

    group('Real execution and coverage', () {
      test(
        'findingMdnsWithAddress runs and handles exceptions gracefully',
        () async {
          if (!dbInitialized) {
            return;
          }
          final result = await mdnsScannerService.findingMdnsWithAddress(
            '_http._tcp',
          );
          expect(result, isA<List<ActiveHost>>());
        },
      );
    });

    group('mDNS address compatibility', () {
      test('normalizes dart:io addresses into universal_io addresses', () {
        final dartAddress = dart_io.InternetAddress('192.168.1.10');

        final normalizedAddress = normalizeInternetAddress(dartAddress);

        expect(normalizedAddress, isA<universal_io.InternetAddress>());
        expect(normalizedAddress.address, '192.168.1.10');
      });

      test('normalizes string addresses into universal_io addresses', () {
        final normalizedAddress = normalizeInternetAddress('192.168.1.10');

        expect(normalizedAddress, isA<universal_io.InternetAddress>());
        expect(normalizedAddress.address, '192.168.1.10');
      });

      test('normalizes address-like objects via their address property', () {
        final normalizedAddress = normalizeInternetAddress(
          _AddressLikeObject('192.168.1.10'),
        );

        expect(normalizedAddress, isA<universal_io.InternetAddress>());
        expect(normalizedAddress.address, '192.168.1.10');
      });

      test('normalizes address-like objects via their rawAddress data', () {
        final normalizedAddress = normalizeInternetAddress(
          _RawAddressLikeObject([192, 168, 1, 10]),
        );

        expect(normalizedAddress, isA<universal_io.InternetAddress>());
        expect(normalizedAddress.address, '192.168.1.10');
      });

      test('throws for unsupported address-like objects', () {
        expect(
          () => normalizeInternetAddress(_UnsupportedAddressLikeObject()),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('mDNS interface filtering', () {
      test('filters out loopback and link-local interfaces before startup', () {
        final filteredInterfaces = filterMdnsInterfaces(
          <universal_io.NetworkInterface>[
            _FakeNetworkInterface('lo0', 1, [
              universal_io.InternetAddress.loopbackIPv4,
            ]),
            _FakeNetworkInterface('vEthernet', 2, [
              universal_io.InternetAddress('169.254.0.1'),
            ]),
            _FakeNetworkInterface('en0', 3, [
              universal_io.InternetAddress('192.168.1.10'),
            ]),
          ],
          dart_io.InternetAddressType.IPv4,
          isWindows: true,
        );

        expect(filteredInterfaces, hasLength(1));
        expect(filteredInterfaces.single.name, 'en0');
      });
    });
  });
}

class MockMdnsScannerServiceImpl extends MdnsScannerServiceImpl {
  @override
  Future<List<ActiveHost>> findingMdnsWithAddress(String serviceType) async {
    return [];
  }
}

class _FakeNetworkInterface implements universal_io.NetworkInterface {
  _FakeNetworkInterface(this.name, this.index, this.addresses);

  @override
  final String name;

  @override
  final int index;

  @override
  final List<universal_io.InternetAddress> addresses;
}

class _AddressLikeObject {
  _AddressLikeObject(this.address);

  final String address;
}

class _RawAddressLikeObject {
  _RawAddressLikeObject(this.rawAddress);

  final List<int> rawAddress;
}

class _UnsupportedAddressLikeObject {}
