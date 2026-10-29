import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:network_tools/src/models/arp_data.dart';
import 'package:universal_io/io.dart';

/// Retreiving ARP packets is only supported for Desktop such as
/// Linux, Windows, and macOS. Dart native doesn't provide a way or rejects
/// call to arp command on mobile such as Android and iOS.
/// Maybe in future dart native will support sending raw packets,
/// so that time we can add implementation for mobile devices.
/// Currenlty this is achieved by process package.
/// Helper class for retrieving and parsing the ARP table on supported desktop platforms.
class ARPTableHelper {
  /// Logger for ARP table operations.
  static final arpLogger = Logger("arp-table-logger");

  bool isMobilePlatform = Platform.isAndroid || Platform.isIOS;
  bool isMacOSPlatform = Platform.isMacOS;
  bool isLinuxPlatform = Platform.isLinux;

  List<String> executeARPCommand() {
    // ARP is not allowed to be run for mobile devices currenlty.
    if (isMobilePlatform) {
      arpLogger.warning("ARP command is not supported on mobile platforms.");
      return [];
    }
    try {
      final result = Process.runSync('arp', ['-a']);
      if (result.exitCode != 0) {
        arpLogger.warning("Failed to execute ARP command: ${result.stderr}");
        return [];
      }
      return const LineSplitter().convert(result.stdout.toString());
    } on ProcessException catch (error) {
      // The arp binary can be missing on minimal systems (containers, some
      // Linux images). Host discovery still works, only MAC data is missing.
      arpLogger.warning("ARP command is unavailable: $error");
      return [];
    } catch (error, stackTrace) {
      arpLogger.warning(
        "Unexpected error while running ARP command: $error",
        error,
        stackTrace,
      );
      return [];
    }
  }

  RegExp _getARPCmdRegExPattern() {
    if (isMacOSPlatform) {
      return RegExp(
        r'(?<host>[\w.?]*)\s\((?<ip>.*)\)\sat\s(?<mac>.*)\son\s(?<intf>\w+)\sifscope\s*(\w*)\s*\[(?<typ>.*)\]',
      );
    } else if (isLinuxPlatform) {
      return RegExp(
        r'(?<host>[\w.?]*)\s\((?<ip>.*)\)\sat\s(?<mac>.*)\s\[(?<typ>.*)\]\son\s(?<intf>\w+)',
      );
    } else {
      // Windows: non-greedy match and trim whitespace
      return RegExp(
        r'(?<ip>[^\s]+)\s+(?<mac>[^\s]+)\s+(?<typ>\w+)',
        caseSensitive: false,
      );
    }
  }

  /// Retrieves the ARP table by running the `arp -a` command on Linux, Windows, and macOS.
  ///
  /// Parses the output and returns a list of [ARPData] objects representing each ARP entry.
  /// Returns an empty list on unsupported platforms (e.g., Android, iOS).
  Future<List<ARPData>> buildTable() async {
    final Map<String, ARPData> arpEntries = {};
    final int startTime = DateTime.now().millisecondsSinceEpoch;
    final entries = executeARPCommand();
    if (entries.isEmpty) {
      arpLogger.warning("No ARP entries found.");
      return [];
    }

    final pattern = _getARPCmdRegExPattern();
    final macPattern = RegExp(r'^([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}$');

    for (final entry in entries) {
      // Skip Windows header and interface lines
      if (entry.trim().isEmpty ||
          entry.startsWith('Interface:') ||
          entry.trim().toLowerCase().startsWith('internet address')) {
        continue;
      }
      final match = pattern.firstMatch(entry);
      if (match == null) {
        continue;
      }
      try {
        final arpData = ARPData.fromRegExpMatch(match);
        final String macAddress = arpData.macAddress;
        if (macAddress == '(incomplete)' || macAddress == '<incomplete>') {
          continue;
        }
        // Localized headers can accidentally match the Windows pattern. Only
        // accept entries that actually contain a MAC address.
        if (!macPattern.hasMatch(macAddress)) {
          arpLogger.fine(
            "Skipping ARP entry with unrecognized MAC address: $entry",
          );
          continue;
        }
        arpLogger.fine("Adding entry to table -> $arpData");
        arpEntries[arpData.iPAddress] = arpData;
      } catch (error) {
        arpLogger.fine("Skipping unparsable ARP entry: $entry ($error)");
      }
    }
    arpLogger.fine(
      "ARP calculation took ${DateTime.now().millisecondsSinceEpoch - startTime} ms with ${arpEntries.length} entries",
    );
    return arpEntries.values.toList();
  }
}
