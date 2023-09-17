import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:network_tools/src/models/arp_data.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ARPTable {
  static final arpLogger = Logger("arp-table-logger");
  static const String tableName = 'ARPPackets';
  static const String columnName = 'iPAddress';

  static Future<List<String>?> entries() async {
    final list = (await (await _db()).query(tableName, columns: [columnName]))
        .map((e) => ARPData.fromJson(e).iPAddress.toString())
        .toList();
    return list;
  }

  static Future<ARPData?> entryFor(String address) async {
    arpLogger.fine('Trying to fetch arp table entry for $address');
    final entries = (await (await _db())
            .query(tableName, where: '$columnName = ?', whereArgs: [address]))
        .map((e) => ARPData.fromJson(e))
        .toList();
    if (entries.isNotEmpty) {
      return entries.first;
    }
    return null;
  }

  static Future<Database> _db() async {
    sqfliteFfiInit();
    final databaseFactory = databaseFactoryFfi;
    final databasesPath = await databaseFactory.getDatabasesPath();
    final path = join(databasesPath, 'localarp.db');
    return databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        singleInstance: false,
        onCreate: (db, version) async {
          await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
          host TEXT,
          iPAddress TEXT PRIMARY KEY UNIQUE,
          macAddress TEXT,
          interfaceName TEXT,
          interfaceType TEXT) 
      ''');
        },
      ),
    );
  }

  static Future<void> buildTable() async {
    final database = await _db();
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
          host: match.groupNames.contains('host')
              ? match.namedGroup("host")
              : null,
          iPAddress: match.namedGroup("ip"),
          macAddress: match.namedGroup("mac"),
          interfaceName: match.groupNames.contains('intf')
              ? match.namedGroup("intf")
              : null,
          interfaceType: match.namedGroup("typ"),
        );
        final key = arpData.iPAddress;
        if (key != null && arpData.macAddress != '(incomplete)') {
          arpLogger.fine("Adding entry to table -> $arpData");
          await database.insert(
            tableName,
            arpData.toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    }
  }
}
