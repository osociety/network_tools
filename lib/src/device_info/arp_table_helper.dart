import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:network_tools/src/models/arp_data.dart';

class ARPTableHelper {
  static final arpLogger = Logger("arp-table-logger");

  static Future<List<ARPData>> buildTable() async {
    final arpEntries = <ARPData>[];
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
