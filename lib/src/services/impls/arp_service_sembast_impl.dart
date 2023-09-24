import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:network_tools/src/device_info/arp_table_helper.dart';
import 'package:network_tools/src/models/arp_data.dart';
import 'package:network_tools/src/services/arp_service.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

@Injectable(as: ARPService)
class ARPServiceSembastImpl extends ARPService {
  static Database? _db;
  static final _store = stringMapStoreFactory.store('arpstore');

  @override
  Future<void> buildTable() async {
    final entries =
        (await ARPTableHelper.buildTable()).map((e) => e.toJson()).toList();
    await _store.addAll(_db!, entries);
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
    _db = await dbFactory.openDatabase('build/network_tools.db');
    return Future.value(this);
  }
}
