import 'dart:async';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:logging/logging.dart';
import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/database/database_service.dart';
import 'package:network_tools/src/database/drift_database.dart';
import 'package:network_tools/src/device_info/vendor_table.dart';
import 'package:network_tools/src/services/repository.dart';

@Injectable(as: Repository<Vendor>)
class VendorRepository implements Repository<Vendor> {
  VendorRepository(this._database);
  static final vendorDriftLogger = Logger("vendor-drift-logger");
  final DatabaseService<AppDatabase> _database;

  @override
  Future<void> build() async {
    final database = await _database.open();
    final oldEntries = await this.entries();
    if (oldEntries.isNotEmpty) {
      vendorDriftLogger.fine(
        "Skipping Mac Vendor table build, old entries found",
      );
      return;
    }

    final entries = (await VendorTable.fetchVendorTable())
        .map(
          (e) => VendorDriftCompanion.insert(
            macPrefix: e.macPrefix,
            vendorName: e.vendorName,
            private: e.private,
            blockType: e.blockType,
            lastUpdate: e.lastUpdate,
          ),
        )
        .toList();
    if (entries.isNotEmpty) {
      await database!.batch((batch) {
        batch.insertAll(database.vendorDrift, entries);
      });
      vendorDriftLogger.fine(
        "Mac Vendor table built with ${entries.length} entries",
      );
    }
  }

  @override
  Future<void> close() async {
    final database = await _database.open();
    database!.close();
  }

  @override
  Future<List<String>> entries() async {
    final database = await _database.open();
    final records = await (database!.select(
      database.vendorDrift,
    )..orderBy([(t) => OrderingTerm(expression: t.id)])).get();

    return records.map((e) => e.macPrefix).toList();
  }

  @override
  Future<Vendor?> entryFor(String address) async {
    final database = await _database.open();
    final records =
        await (database!.select(database.vendorDrift)..where(
              (t) => t.macPrefix.equals(VendorTable.noColonString(address)),
            ))
            .get();
    if (records.isNotEmpty) {
      vendorDriftLogger.fine("Found Vendor entry for address: $address");
      return Vendor.fromDriftData(records.first);
    }
    vendorDriftLogger.fine("No Vendor entry found for address: $address");
    return null;
  }

  @override
  Future<bool> clear() async {
    final database = await _database.open();
    await database!.delete(database.vendorDrift).go();
    return true;
  }
}
