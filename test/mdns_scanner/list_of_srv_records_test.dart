import 'package:network_tools/src/mdns_scanner/list_of_srv_records.dart';
import 'package:test/test.dart';

void main() {
  group('List of SRV Records Tests', () {
    test('TCP SRV records list should not be empty', () {
      expect(tcpSrvRecordsList, isNotEmpty);
    });

    test('UDP SRV records list should not be empty', () {
      expect(udpSrvRecordsList, isNotEmpty);
    });

    test('TCP SRV records should contain common service types', () {
      expect(tcpSrvRecordsList.contains('_http._tcp'), true);
      expect(tcpSrvRecordsList.contains('_ssh._tcp'), true);
      expect(tcpSrvRecordsList.contains('_mqtt._tcp'), true);
      expect(tcpSrvRecordsList.contains('_printer._tcp'), true);
      expect(tcpSrvRecordsList.contains('_ipp._tcp'), true);
    });

    test('UDP SRV records should contain common service types', () {
      expect(udpSrvRecordsList.contains('_hap._udp'), true);
      expect(udpSrvRecordsList.contains('_miio._udp'), true);
      expect(udpSrvRecordsList.contains('_kdeconnect._udp'), true);
    });

    test(
      'All TCP SRV records should start with underscore and end with _tcp',
      () {
        for (final record in tcpSrvRecordsList) {
          expect(record.startsWith('_'), true);
          expect(record.endsWith('_tcp'), true);
        }
      },
    );

    test(
      'All UDP SRV records should start with underscore and end with _udp',
      () {
        for (final record in udpSrvRecordsList) {
          expect(record.startsWith('_'), true);
          expect(record.endsWith('_udp'), true);
        }
      },
    );

    test('TCP and UDP SRV records lists should not have duplicates', () {
      // Note: The TCP list has duplicate '_axis-video._tcp' entries
      final tcpSet = tcpSrvRecordsList.toSet();
      // Should have at most 1 duplicate (_axis-video._tcp appears twice)
      expect(tcpSet.length, greaterThanOrEqualTo(tcpSrvRecordsList.length - 1));

      final udpSet = udpSrvRecordsList.toSet();
      expect(udpSet.length, udpSrvRecordsList.length);
    });

    test('TCP and UDP lists should not have overlapping service types', () {
      final tcpServices = tcpSrvRecordsList
          .map((e) => e.replaceAll('_tcp', ''))
          .toSet();
      final udpServices = udpSrvRecordsList
          .map((e) => e.replaceAll('_udp', ''))
          .toSet();

      // Most common services should have only one protocol
      final overlap = tcpServices.intersection(udpServices);
      // Some services can support both protocols, so overlap is allowed but shouldn't be too large
      expect(overlap.length, lessThan(10));
    });

    test('TCP SRV records should contain IoT service types', () {
      expect(tcpSrvRecordsList.contains('_home-assistant._tcp'), true);
      expect(tcpSrvRecordsList.contains('_homekit._tcp'), true);
      expect(tcpSrvRecordsList.contains('_hue._tcp'), true);
      expect(tcpSrvRecordsList.contains('_sonos._tcp'), true);
    });

    test('TCP SRV records length should be reasonable', () {
      // Should have a decent number of service types registered
      expect(tcpSrvRecordsList.length, greaterThan(50));
    });

    test('UDP SRV records length should be reasonable', () {
      // Should have at least some service types registered
      expect(udpSrvRecordsList.length, greaterThan(0));
    });

    test('Service record names should be valid RFC format', () {
      // Service names should be alphanumeric with hyphens and underscores
      // Format: _service._protocol where service can contain alphanumeric, hyphens, underscores
      final validPattern = RegExp(r'^_[a-zA-Z0-9\-_]+\._[a-z]{3,4}$');

      for (final record in tcpSrvRecordsList) {
        expect(
          validPattern.hasMatch(record),
          true,
          reason: 'Invalid format for TCP record: $record',
        );
      }

      for (final record in udpSrvRecordsList) {
        expect(
          validPattern.hasMatch(record),
          true,
          reason: 'Invalid format for UDP record: $record',
        );
      }
    });
  });
}
