import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/models/drift/arp_data.dart';
import 'package:path/path.dart' as path;
part 'drift_database.g.dart';

@DriftDatabase(tables: [ARPDrift])
class AppDatabase extends _$AppDatabase {
  // After generating code, this class needs to define a `schemaVersion` getter
  // and a constructor telling drift where the database should be stored.
  // These are described in the getting started guide: https://drift.simonbinder.eu/setup/
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  /// Creates lookup indexes for the repository queries.
  ///
  /// Without them every ARP lookup scans the whole ARP table.
  Future<void> ensureIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_arp_ip_address '
      'ON a_r_p_drift (i_p_address)',
    );
  }

  static QueryExecutor _openConnection() {
    return NativeDatabase.createInBackground(
      File(path.join(dbDirectory, 'network_tools_v1')),
    );
  }
}
