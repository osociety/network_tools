import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
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
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return NativeDatabase.createInBackground(
      File(path.join(Directory.current.path, 'network_tools')),
    );
  }
}
