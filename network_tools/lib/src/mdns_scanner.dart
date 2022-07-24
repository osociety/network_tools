import 'dart:io';

import 'package:dart_ping/dart_ping.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/list_of_srv_records.dart';
import 'package:network_tools/src/models/mdns_info.dart';

class MdnsScanner {
  /// This method searching for all the mdns devices in the network.
  /// TODO: The implementation is **Lacking!** and will not find all the
  /// TODO: results that actual exist in the network!, only some of them.
  /// TODO: This is because missing functionality in dart
  /// TODO: https://github.com/flutter/flutter/issues/97210
  static Future<List<ActiveHost>> searchMdnsDevices() async {
    final List<Future<List<ActiveHost>>> activeHostListsFuture = [];
    for (final String srvRecord in srvRecordsList) {
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
          mdnsName: srv.target,
          mdnsPort: srv.port,
          mdnsDomainName: ptr.domainName,
          mdnsServiceType: serviceType,
        );
        mdnsFoundList.add(mdnsFound);
      }
    }
    client.stop();

    final List<ActiveHost> listOfActiveHost = [];
    for (final MdnsInfo foundMdns in mdnsFoundList) {
      final String hostIp =
          (await InternetAddress.lookup(foundMdns.mdnsName))[0].address;

      final ActiveHost tempHost = ActiveHost(
        hostIp,
        foundMdns.getOnlyTheStartOfMdnsName(),
        await getPingData(hostIp),
        mdnsInfo: foundMdns,
      );
      listOfActiveHost.add(tempHost);
    }

    return listOfActiveHost;
  }

  static Future<PingData> getPingData(String host) async {
    const int timeoutInSeconds = 1;

    await for (final PingData pingData
        in Ping(host, count: 1, timeout: timeoutInSeconds).stream) {
      final PingResponse? response = pingData.response;
      if (response != null) {
        final Duration? time = response.time;
        if (time != null) {
          return pingData;
        }
      }
    }
    return const PingData();
  }
}
