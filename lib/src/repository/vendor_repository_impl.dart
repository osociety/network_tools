import 'package:injectable/injectable.dart';
import 'package:logging/logging.dart';
import 'package:network_tools/src/device_info/vendor_map.dart';
import 'package:network_tools/src/device_info/vendor_table.dart';
import 'package:network_tools/src/models/vendor.dart';
import 'package:network_tools/src/repository/repository.dart';

@Injectable(as: Repository<Vendor>)
class VendorRepository implements Repository<Vendor> {
  static final _logger = Logger('VendorRepository');

  @override
  Future<void> build() async {
    _logger.fine('Vendor map loaded with ${kVendorMap.length} entries');
  }

  @override
  Future<void> close() async {}

  @override
  Future<List<String>> entries() async => kVendorMap.keys.toList();

  @override
  Future<Vendor?> entryFor(String address) async {
    final hex = VendorTable.normalizedHex(address);
    // Longest match wins: an MA-S, MA-M or IAB sub-block is registered to its
    // own vendor even when the MA-L block containing it is not.
    for (var i = 0; i < VendorTable.prefixLengths.length; i++) {
      final length = VendorTable.prefixLengths[i];
      if (hex.length < length) continue;
      final prefix = hex.substring(0, length);
      final data = kVendorMap[prefix];
      if (data == null) continue;
      _logger.fine('Found Vendor entry for address: $address');
      return Vendor(
        macPrefix: prefix,
        vendorName: data.$1,
        private: data.$2,
        blockType: data.$3,
        lastUpdate: data.$4,
      );
    }
    _logger.fine('No Vendor entry found for address: $address');
    return null;
  }

  @override
  Future<bool> clear() async => true;
}
