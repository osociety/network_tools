import 'dart:async';

import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/database/drift_database.dart';
import 'package:network_tools/src/device_info/arp_table_helper.dart';
import 'package:network_tools/src/services/arp_service.dart';

class ARPServiceDriftImpl extends ARPService {
  static final arpDriftLogger = Logger("arp-drift-logger");
  static final AppDatabase database = AppDatabase();

  @override
  Future<void> build() async {
    final oldEntries = await this.entries();
    if (oldEntries.isNotEmpty) {
      arpDriftLogger.fine("Skipping ARP table build, old entries found");
      return;
    }
    final entries = (await ARPTableHelper.buildTable())
        .map(
          (e) => ARPDriftCompanion.insert(
            iPAddress: e.iPAddress,
            macAddress: e.macAddress,
            hostname: e.hostname,
            interfaceName: e.interfaceName,
            interfaceType: e.interfaceType,
            createdAt: DateTime.now(),
          ),
        )
        .toList();
    if (entries.isNotEmpty) {
      await database.batch((batch) {
        batch.insertAll(database.aRPDrift, entries);
      });
      arpDriftLogger.fine("ARP table built with ${entries.length} entries");
    }
  }

  @override
  void close() {
    database.close();
  }

  Future<List<ARPDriftData>> _fullEntries() async {
    final records = await (database.select(
      database.aRPDrift,
    )..orderBy([(t) => OrderingTerm(expression: t.id)])).get();

    return records.toList();
  }

  @override
  Future<List<String>> entries() async {
    final records = await (database.select(
      database.aRPDrift,
    )..orderBy([(t) => OrderingTerm(expression: t.id)])).get();

    return records.map((e) => e.iPAddress).toList();
  }

  @override
  Future<ARPData?> entryFor(String address) async {
    final records = await (database.select(
      database.aRPDrift,
    )..where((t) => t.iPAddress.equals(address))).get();
    if (records.isNotEmpty) {
      arpDriftLogger.fine("Found ARP entry for address: $address");
      return ARPData.fromDriftData(records.first);
    }
    arpDriftLogger.fine("No ARP entry found for address: $address");
    return null;
  }

  @override
  Future<bool> clear() async {
    final oldEnteries = await _fullEntries();
    if (oldEnteries.isNotEmpty) {
      arpDriftLogger.fine("Skipping ARP table build, old entries found");
      bool hasOldEntries = false;
      for (final entry in oldEnteries) {
        // Delete records older than 1 hour
        if (entry.createdAt.isBefore(
          DateTime.now().subtract(const Duration(hours: 1)),
        )) {
          hasOldEntries = true;
          break;
        }
      }
      if (hasOldEntries) {
        //Delete entire table data
        await database.delete(database.aRPDrift).go();
        arpDriftLogger.fine("Deleting all ARP entries older than 1 hour");
      }
      return true;
    }
    return false;
  }
}
