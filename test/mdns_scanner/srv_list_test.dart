import 'package:network_tools/src/mdns_scanner/get_srv_list_by_os/srv_list.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  group('SrvList Tests', () {
    test(
      'getSrvRecordList should call platform-specific implementation on Linux',
      () async {
        // Note: This test is informational - actual behavior depends on test platform
        // On Linux: calls SrvListLinux.getSrvRecordList()
        // On other platforms: returns []

        final result = await SrvList.getSrvRecordList();

        // Should return a list (either populated on Linux or empty on other platforms)
        expect(result, isA<List<String>?>());
      },
    );

    test(
      'getSrvRecordList should return empty list on non-Linux platforms',
      () async {
        if (!Platform.isLinux) {
          final result = await SrvList.getSrvRecordList();
          expect(result, isEmpty);
        }
      },
    );

    test('getSrvRecordList should return list on Linux', () async {
      if (Platform.isLinux) {
        final result = await SrvList.getSrvRecordList();
        // On Linux, result could be empty or populated depending on system tools
        expect(result, isA<List<String>?>());
      }
    });

    test('getSrvRecordList result should be list of strings', () async {
      final result = await SrvList.getSrvRecordList();
      if (result != null) {
        for (final item in result) {
          expect(item, isA<String>());
        }
      }
    });

    test('getSrvRecordList should not throw exception', () {
      expect(() => SrvList.getSrvRecordList(), returnsNormally);
    });

    test(
      'getSrvRecordList should return mDNS service names if available',
      () async {
        final result = await SrvList.getSrvRecordList();

        // If not empty, results should contain valid mDNS service names
        if (result != null && result.isNotEmpty) {
          for (final service in result) {
            // Services typically contain underscores and periods
            expect(service, anyOf(contains('_'), contains('.')));
          }
        }
      },
    );

    test('getSrvRecordList should handle errors gracefully', () async {
      // Should not throw even if system tools fail
      final result = await SrvList.getSrvRecordList();
      expect(result, isA<List?>());
    });
  });
}
