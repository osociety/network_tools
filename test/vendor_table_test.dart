// dart

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/device_info/vendor_table.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

// Mocks
class MockHttpClient extends Mock implements http.Client {}

void main() {
  group('VendorTable', () {
    group('noColonString', () {
      test('parses colon-separated MAC', () {
        expect(VendorTable.noColonString('aa:bb:cc:dd:ee:ff'), 'AABBCC');
      });
      test('parses dash-separated MAC', () {
        expect(VendorTable.noColonString('aa-bb-cc-dd-ee-ff'), 'AABBCC');
      });
      test('parses uppercase MAC', () {
        expect(VendorTable.noColonString('AA:BB:CC:DD:EE:FF'), 'AABBCC');
      });
      test('parses mixed-case MAC', () {
        expect(VendorTable.noColonString('Aa:Bb:Cc:Dd:Ee:Ff'), 'AABBCC');
      });
      test('parses dot-separated MAC', () {
        expect(VendorTable.noColonString('aabb.ccdd.eeff'), 'AABBCC');
      });
      test('parses MAC without separators', () {
        expect(VendorTable.noColonString('aabbccddeeff'), 'AABBCC');
      });
      test('keeps short input unchanged instead of throwing', () {
        expect(VendorTable.noColonString('aabb'), 'AABB');
      });
    });

    setUpAll(() {
      registerFallbackValue(Uri.parse('http://localhost'));
      registerFallbackValue(<String, String>{});
    });
    group('fetchVendorTable', () {
      const testCsvContent =
          'Mac Prefix,Vendor Name,Private,Block Type,Last Update\n'
          '00:00:0C,"Cisco Systems, Inc",false,MA-L,2015/11/17\n'
          '00:00:0D,FIBRONICS LTD.,false,MA-L,2015/11/17\n'
          '00:00:0E,FUJITSU LIMITED,false,MA-L,2018/10/13\n'
          '00:00:1B,"Novell, Inc.",false,MA-L,2016/04/27\n';
      final csvBytes = utf8.encode(testCsvContent);

      late String testDbDir;
      late String testCsvPath;
      late File testFile;

      setUp(() async {
        // Setup a temp directory for dbDirectory
        final tempDir = Directory.systemTemp.createTempSync();
        testDbDir = tempDir.path;
        testCsvPath = p.join(testDbDir, "mac-vendors-export.csv");
        dbDirectory = testDbDir;
        testFile = File(testCsvPath);
        // Remove file if exists
        if (await testFile.exists()) {
          await testFile.delete();
        }
      });

      tearDown(() async {
        if (await testFile.exists()) {
          await testFile.delete();
        }
        Directory(testDbDir).deleteSync(recursive: true);
      });

      test('downloads and parses CSV if file does not exist', () async {
        final mockClient = MockHttpClient();
        when(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response.bytes(csvBytes, 200));

        final vendors = await VendorTable.fetchVendorTable(client: mockClient);
        expect(await testFile.exists(), isTrue);
        expect(vendors.length, 4);
        expect(vendors[0].macPrefix, '00000C');
        expect(vendors[0].vendorName, 'Cisco Systems, Inc');
        expect(vendors[1].macPrefix, '00000D');
        expect(vendors[1].vendorName, 'FIBRONICS LTD.');
        expect(vendors[2].macPrefix, '00000E');
        expect(vendors[2].vendorName, 'FUJITSU LIMITED');
        expect(vendors[3].macPrefix, '00001B');
        expect(vendors[3].vendorName, 'Novell, Inc.');
      });

      test('does not download if file exists, just parses', () async {
        await testFile.writeAsBytes(csvBytes);
        final mockClient = MockHttpClient();
        // Should not call get
        final vendors = await VendorTable.fetchVendorTable(client: mockClient);
        expect(vendors.length, 4);
        expect(vendors[0].macPrefix, '00000C');
        expect(vendors[0].vendorName, 'Cisco Systems, Inc');
        expect(vendors[1].macPrefix, '00000D');
        expect(vendors[1].vendorName, 'FIBRONICS LTD.');
        expect(vendors[2].macPrefix, '00000E');
        expect(vendors[2].vendorName, 'FUJITSU LIMITED');
        expect(vendors[3].macPrefix, '00001B');
        expect(vendors[3].vendorName, 'Novell, Inc.');
      });

      test('removes header and parses only data rows', () async {
        await testFile.writeAsBytes(csvBytes);
        final vendors = await VendorTable.fetchVendorTable();
        // Should not include the header row, and all macPrefix values should be 6 hex digits
        expect(vendors.length, 4);
        expect(vendors.every((v) => v.macPrefix.length == 6), isTrue);
        expect(vendors.every((v) => v.macPrefix != 'Mac Prefix'), isTrue);
      });

      test(
        'returns empty list when download fails with a non-200 status',
        () async {
          final mockClient = MockHttpClient();
          when(
            () => mockClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response('not found', 404));

          final vendors = await VendorTable.fetchVendorTable(
            client: mockClient,
          );

          expect(vendors, isEmpty);
          expect(await testFile.exists(), isFalse);
        },
      );

      test('returns empty list when the download throws', () async {
        final mockClient = MockHttpClient();
        when(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).thenThrow(http.ClientException('network is unreachable'));

        final vendors = await VendorTable.fetchVendorTable(client: mockClient);

        expect(vendors, isEmpty);
        expect(await testFile.exists(), isFalse);
      });

      test('removes a corrupt cache and returns empty list', () async {
        // Invalid UTF-8 bytes make the CSV parsing fail.
        await testFile.writeAsBytes([0xC3, 0x28, 0x0A]);

        final vendors = await VendorTable.fetchVendorTable();

        expect(vendors, isEmpty);
        expect(await testFile.exists(), isFalse);
      });

      test('returns empty list for an empty file', () async {
        await testFile.writeAsBytes([]);

        final vendors = await VendorTable.fetchVendorTable();

        expect(vendors, isEmpty);
        expect(await testFile.exists(), isFalse);
      });

      test('parses rows with missing optional columns', () async {
        await testFile.writeAsString(
          'Mac Prefix,Vendor Name,Private,Block Type,Last Update\n'
          '00:00:0C,Cisco\n'
          '00:00:0D,Vendor2,false,MA-L,2015/11/17\n',
        );

        final vendors = await VendorTable.fetchVendorTable();

        expect(vendors.length, 2);
        expect(vendors[0].macPrefix, '00000C');
        expect(vendors[0].vendorName, 'Cisco');
        expect(vendors[0].private, '');
        expect(vendors[0].blockType, '');
        expect(vendors[0].lastUpdate, '');
      });
    });
  });
}
