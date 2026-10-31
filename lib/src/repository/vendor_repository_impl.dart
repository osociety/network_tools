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
    final prefix = VendorTable.noColonString(address);
    final data = kVendorMap[prefix];
    if (data == null) {
      _logger.fine('No Vendor entry found for address: $address');
      return null;
    }
    _logger.fine('Found Vendor entry for address: $address');
    return Vendor(
      macPrefix: prefix,
      vendorName: data.$1,
      private: data.$2,
      blockType: data.$3,
      lastUpdate: data.$4,
    );
  }

  @override
  Future<bool> clear() async => true;
}
