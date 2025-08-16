import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/network_tools_utils.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

/// Provides utilities for mapping MAC addresses to vendor information using a local CSV file.
class VendorTable {
  static String noColonString(String macAddress) {
    final pattern = macAddress.contains(':') ? ':' : '-';
    return macAddress.split(pattern).sublist(0, 3).join().toUpperCase();
  }

  static Future<List<Vendor>> fetchVendorTable() async {
    //Download and store
    final csvPath = p.join(dbDirectory, "mac-vendors-export.csv");
    final file = File(csvPath);
    if (!await file.exists()) {
      logger.fine("Downloading mac-vendors-export.csv from network_tools");
      final response = await http.get(
        Uri.https(
          "raw.githubusercontent.com",
          "osociety/network_tools/main/lib/assets/mac-vendors-export.csv",
        ),
      );
      file.writeAsBytesSync(response.bodyBytes);
      logger.fine("Downloaded mac-vendors-export.csv successfully");
    } else {
      logger.fine("File mac-vendors-export.csv already exists");
    }

    final input = file.openRead();

    List<List<String>> fields = (await input
        .transform(utf8.decoder)
        .transform(const CsvToListConverter(eol: '\n'))
        .toList())
        .map<List<String>>((row) => row.map((e) => e.toString()).toList())
        .toList();
    // Remove header from csv
    fields = fields.sublist(1);
    return fields.map((field) => Vendor.fromCSVField(field)).toList();
  }
}
