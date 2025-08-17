import 'dart:async';

import 'package:drift/drift.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/database/database_service.dart';
import 'package:network_tools/src/database/drift_database.dart';

class MockDatabaseService extends Mock implements DatabaseService<AppDatabase> {
  @override
  Future<AppDatabase?> open() async => MockAppDatabase() as AppDatabase;
}

class MockAppDatabase extends Mock implements AppDatabase {
  @override
  SimpleSelectStatement<T, R> select<T extends HasResultSet, R>(
    ResultSetImplementation<T, R> table, {
    bool distinct = false,
  }) =>
      super.noSuchMethod(
            Invocation.method(#select, [table], {#distinct: distinct}),
          )
          as SimpleSelectStatement<T, R>;

  @override
  $ARPDriftTable get aRPDrift =>
      super.noSuchMethod(Invocation.getter(#aRPDrift)) as $ARPDriftTable;

  @override
  Future<void> batch(FutureOr<void> Function(Batch) action) => Future.value();

  @override
  Future<void> close() => Future.value();

  @override
  DeleteStatement<T, D> delete<T extends Table, D>(TableInfo<T, D> table) =>
      super.noSuchMethod(Invocation.method(#delete, [table]))
          as DeleteStatement<T, D>;
}

class MockARPTableHelper extends Mock {
  Future<List<ARPData>> buildTable() => Future.value(<ARPData>[]);
}

// ignore: subtype_of_sealed_class
class MockSelectStatement extends Mock
    implements SimpleSelectStatement<$ARPDriftTable, ARPDriftData> {
  @override
  Future<List<ARPDriftData>> get() => Future.value(<ARPDriftData>[]);
}

// ignore: avoid_implementing_value_types
class MockARPDriftTable extends Mock implements $ARPDriftTable {}

class MockBatch extends Mock {}

class MockDeleteStatement extends Mock {}
