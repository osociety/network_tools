import 'package:drift/drift.dart';

class ARPDrift extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get iPAddress => text()();
  TextColumn get hostname => text()();
  TextColumn get interfaceName => text()();
  TextColumn get interfaceType => text()();
  TextColumn get macAddress => text()();
  DateTimeColumn get createdAt => dateTime().nullable()();
}
