import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/network_tools_utils.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

class VendorTable {
  static Map<dynamic, dynamic> _vendorTableMap = {};

  static Future<Vendor?> getVendor(Future<ARPData?> arpDataFuture) async {
    final arpData = await arpDataFuture;
    if (arpData != null) {
      if (arpData.notNullMacAddress) {
        await createVendorTableMap();
        final pattern = arpData.macAddress.contains(':') ? ':' : '-';
        return _vendorTableMap[
            arpData.macAddress.split(pattern).sublist(0, 3).join()] as Vendor?;
      }
    }
    return null;
  }

  static Future<void> createVendorTableMap() async {
    if (_vendorTableMap.keys.isEmpty) {
      _vendorTableMap = await _fetchVendorTable();
    }
    return;
  }

  static Future<Map<dynamic, dynamic>> _fetchVendorTable() async {
    //Download and store
    final csvPath = p.join(dbDirectory, "mac-vendors-export.csv");
    final file = File(csvPath);
    if (!await file.exists()) {
      log.fine("Downloading mac-vendors-export.csv from network_tools");
      final response = await http.get(
        Uri.https(
          "raw.githubusercontent.com",
          "osociety/network_tools/main/lib/assets/mac-vendors-export.csv",
        ),
      );
      file.writeAsBytesSync(response.bodyBytes);
      log.fine("Downloaded mac-vendors-export.csv successfully");
    } else {
      log.fine("File mac-vendors-export.csv already exists");
    }

    final input = file.openRead();

    List<List<dynamic>> fields = await input
        .transform(utf8.decoder)
        .transform(const CsvToListConverter(eol: '\n'))
        .toList();
    // Remove header from csv
    fields = fields.sublist(1);

    final result = {};

    for (final field in fields) {
      final vendor = Vendor.fromCSVField(field);
      // print('Vendor mac split : ${vendor.macPrefix.split(":").join()}');
      result[vendor.macPrefix.split(":").join()] = vendor;
    }
    return result;
  }
}
