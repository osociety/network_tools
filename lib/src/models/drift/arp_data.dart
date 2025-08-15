import 'package:drift/drift.dart';

class ARPDrift extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get iPAddress => text().withLength(min: 1, max: 39)();
  TextColumn get hostname => text()();
  TextColumn get interfaceName => text()();
  TextColumn get interfaceType => text()();
  TextColumn get macAddress => text().withLength(min: 1, max: 17)();
  DateTimeColumn get createdAt => dateTime().nullable()();
}
