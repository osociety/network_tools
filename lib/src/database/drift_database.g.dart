// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drift_database.dart';

// ignore_for_file: type=lint
class $ARPDriftTable extends ARPDrift
    with TableInfo<$ARPDriftTable, ARPDriftData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ARPDriftTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _iPAddressMeta = const VerificationMeta(
    'iPAddress',
  );
  @override
  late final GeneratedColumn<String> iPAddress = GeneratedColumn<String>(
    'i_p_address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hostnameMeta = const VerificationMeta(
    'hostname',
  );
  @override
  late final GeneratedColumn<String> hostname = GeneratedColumn<String>(
    'hostname',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _interfaceNameMeta = const VerificationMeta(
    'interfaceName',
  );
  @override
  late final GeneratedColumn<String> interfaceName = GeneratedColumn<String>(
    'interface_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _interfaceTypeMeta = const VerificationMeta(
    'interfaceType',
  );
  @override
  late final GeneratedColumn<String> interfaceType = GeneratedColumn<String>(
    'interface_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _macAddressMeta = const VerificationMeta(
    'macAddress',
  );
  @override
  late final GeneratedColumn<String> macAddress = GeneratedColumn<String>(
    'mac_address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    iPAddress,
    hostname,
    interfaceName,
    interfaceType,
    macAddress,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'a_r_p_drift';
  @override
  VerificationContext validateIntegrity(
    Insertable<ARPDriftData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('i_p_address')) {
      context.handle(
        _iPAddressMeta,
        iPAddress.isAcceptableOrUnknown(data['i_p_address']!, _iPAddressMeta),
      );
    } else if (isInserting) {
      context.missing(_iPAddressMeta);
    }
    if (data.containsKey('hostname')) {
      context.handle(
        _hostnameMeta,
        hostname.isAcceptableOrUnknown(data['hostname']!, _hostnameMeta),
      );
    } else if (isInserting) {
      context.missing(_hostnameMeta);
    }
    if (data.containsKey('interface_name')) {
      context.handle(
        _interfaceNameMeta,
        interfaceName.isAcceptableOrUnknown(
          data['interface_name']!,
          _interfaceNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_interfaceNameMeta);
    }
    if (data.containsKey('interface_type')) {
      context.handle(
        _interfaceTypeMeta,
        interfaceType.isAcceptableOrUnknown(
          data['interface_type']!,
          _interfaceTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_interfaceTypeMeta);
    }
    if (data.containsKey('mac_address')) {
      context.handle(
        _macAddressMeta,
        macAddress.isAcceptableOrUnknown(data['mac_address']!, _macAddressMeta),
      );
    } else if (isInserting) {
      context.missing(_macAddressMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ARPDriftData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ARPDriftData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      iPAddress:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}i_p_address'],
          )!,
      hostname:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}hostname'],
          )!,
      interfaceName:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}interface_name'],
          )!,
      interfaceType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}interface_type'],
          )!,
      macAddress:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}mac_address'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
    );
  }

  @override
  $ARPDriftTable createAlias(String alias) {
    return $ARPDriftTable(attachedDatabase, alias);
  }
}

class ARPDriftData extends DataClass implements Insertable<ARPDriftData> {
  final int id;
  final String iPAddress;
  final String hostname;
  final String interfaceName;
  final String interfaceType;
  final String macAddress;
  final DateTime createdAt;
  const ARPDriftData({
    required this.id,
    required this.iPAddress,
    required this.hostname,
    required this.interfaceName,
    required this.interfaceType,
    required this.macAddress,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['i_p_address'] = Variable<String>(iPAddress);
    map['hostname'] = Variable<String>(hostname);
    map['interface_name'] = Variable<String>(interfaceName);
    map['interface_type'] = Variable<String>(interfaceType);
    map['mac_address'] = Variable<String>(macAddress);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ARPDriftCompanion toCompanion(bool nullToAbsent) {
    return ARPDriftCompanion(
      id: Value(id),
      iPAddress: Value(iPAddress),
      hostname: Value(hostname),
      interfaceName: Value(interfaceName),
      interfaceType: Value(interfaceType),
      macAddress: Value(macAddress),
      createdAt: Value(createdAt),
    );
  }

  factory ARPDriftData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ARPDriftData(
      id: serializer.fromJson<int>(json['id']),
      iPAddress: serializer.fromJson<String>(json['iPAddress']),
      hostname: serializer.fromJson<String>(json['hostname']),
      interfaceName: serializer.fromJson<String>(json['interfaceName']),
      interfaceType: serializer.fromJson<String>(json['interfaceType']),
      macAddress: serializer.fromJson<String>(json['macAddress']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'iPAddress': serializer.toJson<String>(iPAddress),
      'hostname': serializer.toJson<String>(hostname),
      'interfaceName': serializer.toJson<String>(interfaceName),
      'interfaceType': serializer.toJson<String>(interfaceType),
      'macAddress': serializer.toJson<String>(macAddress),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ARPDriftData copyWith({
    int? id,
    String? iPAddress,
    String? hostname,
    String? interfaceName,
    String? interfaceType,
    String? macAddress,
    DateTime? createdAt,
  }) => ARPDriftData(
    id: id ?? this.id,
    iPAddress: iPAddress ?? this.iPAddress,
    hostname: hostname ?? this.hostname,
    interfaceName: interfaceName ?? this.interfaceName,
    interfaceType: interfaceType ?? this.interfaceType,
    macAddress: macAddress ?? this.macAddress,
    createdAt: createdAt ?? this.createdAt,
  );
  ARPDriftData copyWithCompanion(ARPDriftCompanion data) {
    return ARPDriftData(
      id: data.id.present ? data.id.value : this.id,
      iPAddress: data.iPAddress.present ? data.iPAddress.value : this.iPAddress,
      hostname: data.hostname.present ? data.hostname.value : this.hostname,
      interfaceName:
          data.interfaceName.present
              ? data.interfaceName.value
              : this.interfaceName,
      interfaceType:
          data.interfaceType.present
              ? data.interfaceType.value
              : this.interfaceType,
      macAddress:
          data.macAddress.present ? data.macAddress.value : this.macAddress,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ARPDriftData(')
          ..write('id: $id, ')
          ..write('iPAddress: $iPAddress, ')
          ..write('hostname: $hostname, ')
          ..write('interfaceName: $interfaceName, ')
          ..write('interfaceType: $interfaceType, ')
          ..write('macAddress: $macAddress, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    iPAddress,
    hostname,
    interfaceName,
    interfaceType,
    macAddress,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ARPDriftData &&
          other.id == this.id &&
          other.iPAddress == this.iPAddress &&
          other.hostname == this.hostname &&
          other.interfaceName == this.interfaceName &&
          other.interfaceType == this.interfaceType &&
          other.macAddress == this.macAddress &&
          other.createdAt == this.createdAt);
}

class ARPDriftCompanion extends UpdateCompanion<ARPDriftData> {
  final Value<int> id;
  final Value<String> iPAddress;
  final Value<String> hostname;
  final Value<String> interfaceName;
  final Value<String> interfaceType;
  final Value<String> macAddress;
  final Value<DateTime> createdAt;
  const ARPDriftCompanion({
    this.id = const Value.absent(),
    this.iPAddress = const Value.absent(),
    this.hostname = const Value.absent(),
    this.interfaceName = const Value.absent(),
    this.interfaceType = const Value.absent(),
    this.macAddress = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ARPDriftCompanion.insert({
    this.id = const Value.absent(),
    required String iPAddress,
    required String hostname,
    required String interfaceName,
    required String interfaceType,
    required String macAddress,
    required DateTime createdAt,
  }) : iPAddress = Value(iPAddress),
       hostname = Value(hostname),
       interfaceName = Value(interfaceName),
       interfaceType = Value(interfaceType),
       macAddress = Value(macAddress),
       createdAt = Value(createdAt);
  static Insertable<ARPDriftData> custom({
    Expression<int>? id,
    Expression<String>? iPAddress,
    Expression<String>? hostname,
    Expression<String>? interfaceName,
    Expression<String>? interfaceType,
    Expression<String>? macAddress,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (iPAddress != null) 'i_p_address': iPAddress,
      if (hostname != null) 'hostname': hostname,
      if (interfaceName != null) 'interface_name': interfaceName,
      if (interfaceType != null) 'interface_type': interfaceType,
      if (macAddress != null) 'mac_address': macAddress,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ARPDriftCompanion copyWith({
    Value<int>? id,
    Value<String>? iPAddress,
    Value<String>? hostname,
    Value<String>? interfaceName,
    Value<String>? interfaceType,
    Value<String>? macAddress,
    Value<DateTime>? createdAt,
  }) {
    return ARPDriftCompanion(
      id: id ?? this.id,
      iPAddress: iPAddress ?? this.iPAddress,
      hostname: hostname ?? this.hostname,
      interfaceName: interfaceName ?? this.interfaceName,
      interfaceType: interfaceType ?? this.interfaceType,
      macAddress: macAddress ?? this.macAddress,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (iPAddress.present) {
      map['i_p_address'] = Variable<String>(iPAddress.value);
    }
    if (hostname.present) {
      map['hostname'] = Variable<String>(hostname.value);
    }
    if (interfaceName.present) {
      map['interface_name'] = Variable<String>(interfaceName.value);
    }
    if (interfaceType.present) {
      map['interface_type'] = Variable<String>(interfaceType.value);
    }
    if (macAddress.present) {
      map['mac_address'] = Variable<String>(macAddress.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ARPDriftCompanion(')
          ..write('id: $id, ')
          ..write('iPAddress: $iPAddress, ')
          ..write('hostname: $hostname, ')
          ..write('interfaceName: $interfaceName, ')
          ..write('interfaceType: $interfaceType, ')
          ..write('macAddress: $macAddress, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ARPDriftTable aRPDrift = $ARPDriftTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [aRPDrift];
}

typedef $$ARPDriftTableCreateCompanionBuilder =
    ARPDriftCompanion Function({
      Value<int> id,
      required String iPAddress,
      required String hostname,
      required String interfaceName,
      required String interfaceType,
      required String macAddress,
      required DateTime createdAt,
    });
typedef $$ARPDriftTableUpdateCompanionBuilder =
    ARPDriftCompanion Function({
      Value<int> id,
      Value<String> iPAddress,
      Value<String> hostname,
      Value<String> interfaceName,
      Value<String> interfaceType,
      Value<String> macAddress,
      Value<DateTime> createdAt,
    });

class $$ARPDriftTableFilterComposer
    extends Composer<_$AppDatabase, $ARPDriftTable> {
  $$ARPDriftTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iPAddress => $composableBuilder(
    column: $table.iPAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hostname => $composableBuilder(
    column: $table.hostname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get interfaceName => $composableBuilder(
    column: $table.interfaceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get interfaceType => $composableBuilder(
    column: $table.interfaceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get macAddress => $composableBuilder(
    column: $table.macAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ARPDriftTableOrderingComposer
    extends Composer<_$AppDatabase, $ARPDriftTable> {
  $$ARPDriftTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iPAddress => $composableBuilder(
    column: $table.iPAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hostname => $composableBuilder(
    column: $table.hostname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get interfaceName => $composableBuilder(
    column: $table.interfaceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get interfaceType => $composableBuilder(
    column: $table.interfaceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get macAddress => $composableBuilder(
    column: $table.macAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ARPDriftTableAnnotationComposer
    extends Composer<_$AppDatabase, $ARPDriftTable> {
  $$ARPDriftTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get iPAddress =>
      $composableBuilder(column: $table.iPAddress, builder: (column) => column);

  GeneratedColumn<String> get hostname =>
      $composableBuilder(column: $table.hostname, builder: (column) => column);

  GeneratedColumn<String> get interfaceName => $composableBuilder(
    column: $table.interfaceName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get interfaceType => $composableBuilder(
    column: $table.interfaceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get macAddress => $composableBuilder(
    column: $table.macAddress,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ARPDriftTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ARPDriftTable,
          ARPDriftData,
          $$ARPDriftTableFilterComposer,
          $$ARPDriftTableOrderingComposer,
          $$ARPDriftTableAnnotationComposer,
          $$ARPDriftTableCreateCompanionBuilder,
          $$ARPDriftTableUpdateCompanionBuilder,
          (
            ARPDriftData,
            BaseReferences<_$AppDatabase, $ARPDriftTable, ARPDriftData>,
          ),
          ARPDriftData,
          PrefetchHooks Function()
        > {
  $$ARPDriftTableTableManager(_$AppDatabase db, $ARPDriftTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ARPDriftTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$ARPDriftTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$ARPDriftTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> iPAddress = const Value.absent(),
                Value<String> hostname = const Value.absent(),
                Value<String> interfaceName = const Value.absent(),
                Value<String> interfaceType = const Value.absent(),
                Value<String> macAddress = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ARPDriftCompanion(
                id: id,
                iPAddress: iPAddress,
                hostname: hostname,
                interfaceName: interfaceName,
                interfaceType: interfaceType,
                macAddress: macAddress,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String iPAddress,
                required String hostname,
                required String interfaceName,
                required String interfaceType,
                required String macAddress,
                required DateTime createdAt,
              }) => ARPDriftCompanion.insert(
                id: id,
                iPAddress: iPAddress,
                hostname: hostname,
                interfaceName: interfaceName,
                interfaceType: interfaceType,
                macAddress: macAddress,
                createdAt: createdAt,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ARPDriftTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ARPDriftTable,
      ARPDriftData,
      $$ARPDriftTableFilterComposer,
      $$ARPDriftTableOrderingComposer,
      $$ARPDriftTableAnnotationComposer,
      $$ARPDriftTableCreateCompanionBuilder,
      $$ARPDriftTableUpdateCompanionBuilder,
      (
        ARPDriftData,
        BaseReferences<_$AppDatabase, $ARPDriftTable, ARPDriftData>,
      ),
      ARPDriftData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ARPDriftTableTableManager get aRPDrift =>
      $$ARPDriftTableTableManager(_db, _db.aRPDrift);
}
