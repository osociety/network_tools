import 'package:injectable/injectable.dart';
import 'package:logging/logging.dart';
import 'package:network_tools/src/device_info/vendor_index.dart';
import 'package:network_tools/src/device_info/vendor_table.dart';
import 'package:network_tools/src/models/vendor.dart';
import 'package:network_tools/src/repository/repository.dart';

@Injectable(as: Repository<Vendor>)
class VendorRepository implements Repository<Vendor> {
  static final _logger = Logger('VendorRepository');

  @override
  Future<void> build() async {
    _logger.fine('Vendor index loaded with ${vendorIndex.length} entries');
  }

  @override
  Future<void> close() async {}

  @override
  Future<List<String>> entries() async => vendorIndex.prefixes.toList();

  @override
  Future<Vendor?> entryFor(String address) async {
    // Longest match wins: an MA-S, MA-M or IAB sub-block is registered to its
    // own vendor even when the MA-L block containing it is not.
    final data = vendorIndex.entryFor(VendorTable.normalizedHex(address));
    if (data == null) {
      _logger.fine('No Vendor entry found for address: $address');
      return null;
    }
    _logger.fine('Found Vendor entry for address: $address');
    return Vendor(
      macPrefix: data.prefix,
      vendorName: data.name,
      private: data.private,
      blockType: data.blockType,
      lastUpdate: data.lastUpdate,
    );
  }

  @override
  Future<bool> clear() async => true;
}
