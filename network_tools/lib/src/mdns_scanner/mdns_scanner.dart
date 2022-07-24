import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';
import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/mdns_scanner/get_srv_list_by_os/srv_list.dart';
import 'package:network_tools/src/mdns_scanner/list_of_srv_records.dart';
import 'package:network_tools/src/models/mdns_info.dart';

class MdnsScanner {
  /// This method searching for all the mdns devices in the network.
  /// Shows only results for IPv4.
  /// TODO: The implementation is **Lacking!** and will not find all the
  /// TODO: results that actual exist in the network!, only some of them.
  /// TODO: This is because missing functionality in dart
  /// TODO: https://github.com/flutter/flutter/issues/97210
  /// TODO: In some cases we resolve this missing functionality using
  /// TODO: specific os tools.
  static Future<List<ActiveHost>> searchMdnsDevices() async {
    List<String> srvRecordListToSearchIn;

    final List<String>? srvRecordsFromOs = await SrvList.getSrvRecordList();

    if (srvRecordsFromOs == null || srvRecordsFromOs.isEmpty) {
      srvRecordListToSearchIn = srvRecordsList;
    } else {
      srvRecordListToSearchIn = srvRecordsFromOs;
    }

    await Future.delayed(const Duration(milliseconds: 5));

    final List<Future<List<ActiveHost>>> activeHostListsFuture = [];
    for (final String srvRecord in srvRecordListToSearchIn) {
      activeHostListsFuture.add(_findingMdnsWithIp(srvRecord));
    }

    final List<ActiveHost> activeHostList = [];

    for (final Future<List<ActiveHost>> activeHostListFuture
        in activeHostListsFuture) {
      activeHostList.addAll(await activeHostListFuture);
    }

    return activeHostList;
  }

  static Future<List<ActiveHost>> _findingMdnsWithIp(String serviceType) async {
    final List<MdnsInfo> mdnsFoundList = [];

    final MDnsClient client = MDnsClient();
    await client.start();

    await for (final PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer(serviceType),
    )) {
      await for (final SrvResourceRecord srv
          in client.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(ptr.domainName),
      )) {
        final MdnsInfo mdnsFound = MdnsInfo(
          mdnsName: srv.name,
          mdnsPort: srv.port,
          mdnsDomainName: ptr.domainName,
          mdnsServiceType: serviceType,
          mdnsSrvTarget: srv.target,
        );
        mdnsFoundList.add(mdnsFound);
      }
    }
    client.stop();

    final List<ActiveHost> listOfActiveHost = [];
    for (final MdnsInfo foundMdns in mdnsFoundList) {
      final String hostIp =
          (await InternetAddress.lookup(foundMdns.mdnsSrvTarget))[0].address;

      final ActiveHost tempHost = ActiveHost(
        hostIp,
        deviceName: foundMdns.getOnlyTheStartOfMdnsName(),
        mdnsInfo: foundMdns,
      );
      listOfActiveHost.add(tempHost);
    }

    return listOfActiveHost;
  }
}
