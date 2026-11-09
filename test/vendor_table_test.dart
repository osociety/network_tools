import 'package:network_tools/src/device_info/vendor_table.dart';
import 'package:test/test.dart';

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

    group('normalizedHex', () {
      test('keeps every octet of a full MAC', () {
        expect(VendorTable.normalizedHex('aa:bb:cc:dd:ee:ff'), 'AABBCCDDEEFF');
      });

      test('strips dash and dot separators', () {
        expect(VendorTable.normalizedHex('aa-bb-cc-dd-ee-ff'), 'AABBCCDDEEFF');
        expect(VendorTable.normalizedHex('aabb.ccdd.eeff'), 'AABBCCDDEEFF');
      });

      test('does not truncate to an MA-L prefix', () {
        expect(VendorTable.normalizedHex('00:1b:c5:00:2a:ab'), '001BC5002AAB');
      });
    });

    group('prefixLengths', () {
      test('probes the most specific IEEE block first', () {
        expect(VendorTable.prefixLengths, [9, 7, 6]);
      });
    });
  });
}
