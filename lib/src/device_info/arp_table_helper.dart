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
class ARPTableHelper {
  static final arpLogger = Logger("arp-table-logger");

  /// Fires arp -a command only on 3 platforms i.e., Linux, Windows, and macOS
  /// and returns the result in form of ARPData after parsing each line.
  static Future<List<ARPData>> buildTable() async {
    final arpEntries = <ARPData>[];
    // ARP is not allowed to be run for mobile devices currenlty.
    if (Platform.isAndroid || Platform.isIOS) return arpEntries;
    final result = await Process.run('arp', ['-a']);
    final entries = const LineSplitter().convert(result.stdout.toString());
    RegExp? pattern;
    if (Platform.isMacOS) {
      pattern = RegExp(
        r'(?<host>[\w.?]*)\s\((?<ip>.*)\)\sat\s(?<mac>.*)\son\s(?<intf>\w+)\sifscope\s*(\w*)\s*\[(?<typ>.*)\]',
      );
    } else if (Platform.isLinux) {
      pattern = RegExp(
        r'(?<host>[\w.?]*)\s\((?<ip>.*)\)\sat\s(?<mac>.*)\s\[(?<typ>.*)\]\son\s(?<intf>\w+)',
      );
    } else {
      pattern = RegExp(r'(?<ip>.*)\s(?<mac>.*)\s(?<typ>.*)');
    }

    for (final entry in entries) {
      final match = pattern.firstMatch(entry);
      if (match != null) {
        final arpData = ARPData(
          hostname: match.groupNames.contains('host')
              ? match.namedGroup("host") ?? ''
              : '',
          iPAddress: match.namedGroup("ip") ?? ARPData.nullIPAddress,
          macAddress: match.namedGroup("mac") ?? ARPData.nullMacAddress,
          interfaceName: match.groupNames.contains('intf')
              ? match.namedGroup("intf") ?? ''
              : '',
          interfaceType: match.namedGroup("typ") ?? ARPData.nullInterfaceType,
        );
        if (arpData.macAddress != '(incomplete)') {
          arpLogger.fine("Adding entry to table -> $arpData");
          arpEntries.add(arpData);
        }
      }
    }
    return arpEntries;
  }
}
