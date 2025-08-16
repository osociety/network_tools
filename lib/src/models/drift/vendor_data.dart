import 'package:drift/drift.dart';

class VendorDrift extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get macPrefix => text()();
  TextColumn get vendorName => text()();
  TextColumn get private => text()();
  TextColumn get blockType => text()();
  TextColumn get lastUpdate => text()();
}
