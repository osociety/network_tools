import 'dart:async';

import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/device_info/arp_table_helper.dart';
import 'package:network_tools/src/services/arp_service.dart';
import 'package:path/path.dart' as p;
import 'package:sembast/sembast_io.dart';

class ARPServiceSembastImpl extends ARPService {
  Database? _db;
  final _store = stringMapStoreFactory.store('arpstore');

  @override
  Future<void> buildTable() async {
    final entries =
        (await ARPTableHelper.buildTable()).map((e) => e.toJson()).toList();
    if (entries.isNotEmpty) {
      await _store.addAll(_db!, entries);
    }
  }

  @override
  void close() {
    _db?.close();
  }

  @override
  Future<List<String?>?> entries() async {
    return (await (_store.find(
      _db!,
      finder: Finder(sortOrders: [SortOrder(ARPData.primaryKeySembast)]),
    ) as FutureOr<List<RecordSnapshot<String, Map<String, Object>>>>))
        .map((e) => e.key)
        .toList();
  }

  @override
  Future<ARPData?> entryFor(String address) async {
    final records = await _store.find(
      _db!,
      finder: Finder(
        filter: Filter.equals(ARPData.primaryKeySembast, address),
      ),
    );

    if (records.isNotEmpty) {
      return ARPData.fromJson(
        records[0].value,
      );
    }
    return null;
  }

  @override
  Future<ARPService> open() async {
    if (_db != null) return Future.value(this);
    final dbFactory = databaseFactoryIo;
    final dbPath = p.join(dbDirectory, 'network_tools.db');
    _db = await dbFactory.openDatabase(dbPath);
    return Future.value(this);
  }
}
