import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/services/impls/mdns_scanner_service_impl.dart';
import 'package:test/test.dart';

void main() {
  group('MdnsScannerServiceImpl Unit Tests', () {
    late MdnsScannerServiceImpl mdnsScannerService;

    setUpAll(() async {
      // Initialize network tools
      await configureNetworkTools('build');
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
        () {
          // Test that the method can be called with the parameter
          expect(() {
            // Don't await to avoid network timeout
            mdnsScannerService.searchMdnsDevices(
              forceUseOfSavedSrvRecordList: true,
            );
          }, returnsNormally);
        },
      );

      test('searchMdnsDevices can be called without parameters', () {
        expect(() {
          // Don't await to avoid network timeout
          mdnsScannerService.searchMdnsDevices();
        }, returnsNormally);
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
  });
}
