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
  Future<void> buildTable() async {
    final oldEnteries = await this.entries();
    if (oldEnteries.isNotEmpty) {
      arpDriftLogger.fine("Skipping ARP table build, old entries found");
      return;
    }
    arpDriftLogger.fine("No old entries found, building ARP table");

    final entries = (await ARPTableHelper.buildTable())
        .map(
          (e) => ARPDriftCompanion.insert(
            iPAddress: e.iPAddress,
            macAddress: e.macAddress,
            hostname: e.hostname,
            interfaceName: e.interfaceName,
            interfaceType: e.interfaceType,
            createdAt: Value(DateTime.now()),
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
    )..where((t) => t.iPAddress.equals(address))).getSingleOrNull();
    if (records != null) {
      return ARPData.fromDriftData(records);
    }
    return null;
  }

  @override
  Future<ARPService> open() {
    return Future.value(this);
  }
}
