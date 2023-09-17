import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:csv/csv.dart';
import 'package:network_tools/src/models/arp_data.dart';
import 'package:network_tools/src/models/vendor.dart';

class VendorTable {
  static Map<dynamic, dynamic> vendorTableMap = {};

  static Future<Vendor?> getVendor(Future<ARPData?> arpDataFuture) async {
    final arpData = await arpDataFuture;
    if (arpData != null) {
      final macAddress = arpData.macAddress;
      if (macAddress != null) {
        if (vendorTableMap.keys.isEmpty) {
          vendorTableMap = await _createVendorTableMap();
        }
        final pattern = macAddress.contains(':') ? ':' : '-';
        // print("Mac address: ${macAddress.split(pattern).sublist(0, 3).join()}");
        return vendorTableMap[macAddress.split(pattern).sublist(0, 3).join()]
            as Vendor?;
      }
    }
    return null;
  }

  static Future<Map<dynamic, dynamic>> _createVendorTableMap() async {
    final receivePort = ReceivePort();
    await Isolate.spawn(_fetchVendorTable, receivePort.sendPort);
    return await receivePort.first as Map<dynamic, dynamic>;
  }

  static Future<void> _fetchVendorTable(SendPort sendPort) async {
    final input = File('lib/assets/mac-vendors-export.csv').openRead();

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

    sendPort.send(result);
    Isolate.exit();
  }
}
