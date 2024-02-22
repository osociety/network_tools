import 'package:multicast_dns/multicast_dns.dart';
import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/mdns_scanner/get_srv_list_by_os/srv_list.dart';
import 'package:network_tools/src/network_tools_utils.dart';
import 'package:universal_io/io.dart';

class MdnsScannerServiceImpl extends MdnsScannerService {
  /// This method searching for all the mdns devices in the network.
  /// TODO: The implementation is **Lacking!** and will not find all the
  /// TODO: results that actual exist in the network!, only some of them.
  /// TODO: This is because missing functionality in dart
  /// TODO: https://github.com/flutter/flutter/issues/97210
  /// TODO: In some cases we resolve this missing functionality using
  /// TODO: specific os tools.

  @override
  Future<List<ActiveHost>> searchMdnsDevices({
    bool forceUseOfSavedSrvRecordList = false,
  }) async {
    List<String> srvRecordListToSearchIn;

    if (forceUseOfSavedSrvRecordList) {
      srvRecordListToSearchIn = tcpSrvRecordsList;
      srvRecordListToSearchIn.addAll(udpSrvRecordsList);
    } else {
      final List<String>? srvRecordsFromOs = await SrvList.getSrvRecordList();

      if (srvRecordsFromOs == null || srvRecordsFromOs.isEmpty) {
        srvRecordListToSearchIn = tcpSrvRecordsList;
        srvRecordListToSearchIn.addAll(udpSrvRecordsList);
      } else {
        srvRecordListToSearchIn = srvRecordsFromOs;
      }
    }

    final List<Future<List<ActiveHost>>> activeHostListsFuture = [];
    for (final String srvRecord in srvRecordListToSearchIn) {
      activeHostListsFuture.add(findingMdnsWithAddress(srvRecord));
    }

    final List<ActiveHost> activeHostList = [];

    for (final Future<List<ActiveHost>> activeHostListFuture
        in activeHostListsFuture) {
      activeHostList.addAll(await activeHostListFuture);
    }

    return activeHostList;
  }

  @override
  Future<List<ActiveHost>> findingMdnsWithAddress(
    String serviceType,
  ) async {
    final MDnsClient client = MDnsClient(
      rawDatagramSocketFactory: (
        dynamic host,
        int port, {
        bool? reuseAddress,
        bool? reusePort,
        int? ttl,
      }) {
        return RawDatagramSocket.bind(
          host,
          port,
          reusePort: !Platform.isWindows && !Platform.isAndroid,
          ttl: ttl!,
        );
      },
    );

    final List<ActiveHost> listOfActiveHost = [];
    await client.start();

    await for (final PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer(serviceType),
    )) {
      await for (final SrvResourceRecord srv
          in client.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(ptr.domainName),
      )) {
        listOfActiveHost.addAll(
          await findAllActiveHostForSrv(
            addressType: InternetAddress.anyIPv4,
            client: client,
            ptr: ptr,
            srv: srv,
          ),
        );
        listOfActiveHost.addAll(
          await findAllActiveHostForSrv(
            addressType: InternetAddress.anyIPv6,
            client: client,
            ptr: ptr,
            srv: srv,
          ),
        );
      }
    }
    client.stop();

    return listOfActiveHost;
  }

  @override
  Future<List<ActiveHost>> findAllActiveHostForSrv({
    required InternetAddress addressType,
    required MDnsClient client,
    required PtrResourceRecord ptr,
    required SrvResourceRecord srv,
  }) async {
    final List<ActiveHost> listOfActiveHost = [];
    try {
      Stream<IPAddressResourceRecord> iPAddressResourceRecordStream;

      if (addressType == InternetAddress.anyIPv4) {
        iPAddressResourceRecordStream = client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(srv.target),
        );
      } else {
        iPAddressResourceRecordStream = client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv6(srv.target),
        );
      }
      await for (final IPAddressResourceRecord ip
          in iPAddressResourceRecordStream) {
        final ActiveHost activeHost = convertSrvToHostName(
          internetAddress: ip.address,
          ptr: ptr,
          srv: srv,
        );

        listOfActiveHost.add(activeHost);
      }
    } catch (e) {
      log.severe(
        'Error finding ip of mdns record ${ptr.name} srv target ${srv.target}, will add it with ip 0.0.0.0\n$e',
      );
      final ActiveHost activeHost = convertSrvToHostName(
        internetAddress: InternetAddress('0.0.0.0'),
        srv: srv,
        ptr: ptr,
      );
      listOfActiveHost.add(activeHost);
    }
    return listOfActiveHost;
  }

  @override
  ActiveHost convertSrvToHostName({
    required InternetAddress internetAddress,
    required PtrResourceRecord ptr,
    required SrvResourceRecord srv,
  }) {
    final MdnsInfo mdnsInfo = MdnsInfo(
      srvResourceRecord: srv,
      ptrResourceRecord: ptr,
    );
    return ActiveHost(
      internetAddress: internetAddress,
      mdnsInfoVar: mdnsInfo,
    );
  }
}
