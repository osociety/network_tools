import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/network_tools_utils.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

/// Provides utilities for mapping MAC addresses to vendor information using a local CSV file.
class VendorTable {
  static const String fileName = 'mac-vendors-export.csv';
  static const Duration downloadTimeout = Duration(seconds: 15);
  static const String downloadUrl =
      'https://raw.githubusercontent.com/osociety/network_tools/main/lib/assets/mac-vendors-export.csv';

  /// Normalizes a MAC address to the upper-case, separator-free prefix that
  /// is stored in the vendor table.
  ///
  /// Accepts colon, dash and dot separated MACs as well as raw hex strings.
  static String noColonString(String macAddress) {
    final String hex = macAddress
        .replaceAll(RegExp('[^0-9a-fA-F]'), '')
        .toUpperCase();
    return hex.length > 6 ? hex.substring(0, 6) : hex;
  }

  /// Loads the vendor table, downloading it on first use.
  ///
  /// Never throws: if the table can neither be downloaded nor parsed, an empty
  /// list is returned and a warning is logged so host discovery can continue
  /// without vendor names.
  static Future<List<Vendor>> fetchVendorTable({http.Client? client}) async {
    final csvPath = p.join(dbDirectory, fileName);
    final file = File(csvPath);
    if (!file.existsSync()) {
      try {
        await _downloadVendorTable(file, client);
      } catch (error, stackTrace) {
        logger.warning(
          'Failed to download vendor table, vendor names will be unavailable: '
          '$error',
          error,
          stackTrace,
        );
        return [];
      }
    }

    try {
      return await _parseVendorTable(file);
    } catch (error, stackTrace) {
      logger.warning(
        'Failed to parse vendor table at $csvPath, removing it so it is '
        'downloaded again on next start: $error',
        error,
        stackTrace,
      );
      try {
        file.deleteSync();
      } catch (deleteError) {
        logger.fine('Could not remove corrupt vendor table: $deleteError');
      }
      return [];
    }
  }

  static Future<void> _downloadVendorTable(
    File file,
    http.Client? client,
  ) async {
    logger.fine('Downloading $fileName from network_tools');
    final httpClient = client ?? http.Client();
    try {
      final Uri uri = Uri.parse(downloadUrl);
      final http.Response response = await httpClient
          .get(uri)
          .timeout(downloadTimeout);
      if (response.statusCode != 200) {
        throw http.ClientException(
          'Unexpected status code ${response.statusCode}',
          uri,
        );
      }
      // Write to a temporary file first so an interrupted download can never
      // replace a previously valid cache with a truncated CSV.
      final tempFile = File('${file.path}.tmp');
      try {
        await tempFile.writeAsBytes(response.bodyBytes, flush: true);
        await tempFile.rename(file.path);
      } catch (_) {
        if (tempFile.existsSync()) {
          tempFile.deleteSync();
        }
        rethrow;
      }
      logger.fine('Downloaded $fileName successfully');
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  static Future<List<Vendor>> _parseVendorTable(File file) async {
    final input = file.openRead();
    final List<List<String>> fields =
        (await input.transform(utf8.decoder).transform(csv.decoder).toList())
            .map<List<String>>((row) => row.map((e) => e.toString()).toList())
            .toList();
    if (fields.isEmpty) {
      throw const FormatException('Vendor table is empty');
    }
    // Remove header from csv
    final List<List<String>> rows = fields.sublist(1);
    return rows
        .where(
          (field) =>
              field.length >= 2 &&
              field[0].trim().isNotEmpty &&
              field[1].trim().isNotEmpty,
        )
        .map(Vendor.fromCSVField)
        .where((vendor) => vendor.macPrefix.isNotEmpty)
        .toList();
  }
}
