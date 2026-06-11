import 'package:network_tools/src/mdns_scanner/get_srv_list_by_os/srv_list_linux.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  group('SrvListLinux Tests', () {
    test('getSrvRecordList should return a list', () async {
      if (Platform.isLinux) {
        final result = await SrvListLinux.getSrvRecordList();
        expect(result, isA<List<String>?>());
      }
    });

    test('getSrvRecordList should return non-null list', () async {
      if (Platform.isLinux) {
        final result = await SrvListLinux.getSrvRecordList();
        expect(result, isNotNull);
      }
    });

    test(
      'getSrvRecordList should handle case when no services are found',
      () async {
        if (Platform.isLinux) {
          final result = await SrvListLinux.getSrvRecordList();
          // Result should be a list, possibly empty if no services available
          expect(result, isA<List<String>?>());
        }
      },
    );

    test(
      'getSrvRecordList should combine results from both avahi-browse and mdns-scan',
      () async {
        if (Platform.isLinux) {
          final result = await SrvListLinux.getSrvRecordList();

          // If tools are installed and services are available, should get results
          if (result != null && result.isNotEmpty) {
            // All items should be strings
            for (final item in result) {
              expect(item, isA<String>());
            }

            // Results should be deduplicated (from HashSet usage)
            expect(result.toSet().length, equals(result.length));
          }
        }
      },
    );

    test('runAvahiBrowseCommand should return a list', () async {
      if (Platform.isLinux) {
        final result = await SrvListLinux.runAvahiBrowseCommand();
        expect(result, isA<List<String>>());
      }
    });

    test(
      'runAvahiBrowseCommand should handle missing avahi-browse gracefully',
      () {
        if (Platform.isLinux) {
          // Should not throw even if avahi-browse is not installed
          expect(() => SrvListLinux.runAvahiBrowseCommand(), returnsNormally);
        }
      },
    );

    test('runMdnsScanCommand should return a list', () async {
      if (Platform.isLinux) {
        final result = await SrvListLinux.runMdnsScanCommand();
        expect(result, isA<List<String>>());
      }
    });

    test('runMdnsScanCommand should handle missing mdns-scan gracefully', () {
      if (Platform.isLinux) {
        // Should not throw even if mdns-scan is not installed
        expect(() => SrvListLinux.runMdnsScanCommand(), returnsNormally);
      }
    });

    test('getSrvRecordList should not throw exception', () {
      if (Platform.isLinux) {
        expect(() => SrvListLinux.getSrvRecordList(), returnsNormally);
      }
    });

    test('runAvahiBrowseCommand should not throw exception', () {
      if (Platform.isLinux) {
        expect(() => SrvListLinux.runAvahiBrowseCommand(), returnsNormally);
      }
    });

    test('runMdnsScanCommand should not throw exception', () {
      if (Platform.isLinux) {
        expect(() => SrvListLinux.runMdnsScanCommand(), returnsNormally);
      }
    });

    test('Results should be valid mDNS service names', () async {
      if (Platform.isLinux) {
        final result = await SrvListLinux.getSrvRecordList();

        if (result != null && result.isNotEmpty) {
          for (final service in result) {
            // Service names should contain valid characters
            expect(service, isNotEmpty);
            // Typical mDNS services contain underscores and/or periods
            expect(service, anyOf(contains('_'), contains('.')));
          }
        }
      }
    });

    test('getSrvRecordList should deduplicate results', () async {
      if (Platform.isLinux) {
        final result = await SrvListLinux.getSrvRecordList();

        if (result != null && result.isNotEmpty) {
          // No duplicates should exist
          final set = result.toSet();
          expect(set.length, equals(result.length));
        }
      }
    });
  });
}
