import 'dart:async';
import 'dart:typed_data';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/mdns_scanner/get_srv_list_by_os/srv_list.dart';
import 'package:network_tools/src/network_tools_utils.dart';
import 'package:universal_io/io.dart';

/// Converts a network address coming from either the Dart IO or universal_io
/// implementation into the package's [InternetAddress] type.
InternetAddress normalizeInternetAddress(dynamic address) {
  if (address is InternetAddress) {
    return address;
  }

  if (address is String) {
    final parsedAddress = InternetAddress.tryParse(address);
    if (parsedAddress != null) {
      return parsedAddress;
    }
  }

  if (address is Object) {
    try {
      final dynamic addressValue = (address as dynamic).address;
      if (addressValue is String) {
        final parsedAddress = InternetAddress.tryParse(addressValue);
        if (parsedAddress != null) {
          return parsedAddress;
        }
      }
    } catch (_) {}

    try {
      final dynamic rawAddress = (address as dynamic).rawAddress;
      if (rawAddress is List<int>) {
        return InternetAddress.fromRawAddress(Uint8List.fromList(rawAddress));
      }
    } catch (_) {}
  }

  throw ArgumentError.value(
    address,
    'address',
    'Unsupported InternetAddress implementation',
  );
}

/// Resolves the bind target for [RawDatagramSocket.bind].
///
/// On Windows, binding with an [InternetAddress] whose hostname is empty fails
/// with errno 10049. Always use the numeric address string instead.
dynamic _mdnsDatagramBindHost(dynamic host) {
  if (host is InternetAddress) {
    return host.address;
  }

  try {
    return normalizeInternetAddress(host).address;
  } catch (_) {
    return host;
  }
}

Future<RawDatagramSocket> _mdnsRawDatagramSocketFactory(
  dynamic host,
  int port, {
  bool? reuseAddress,
  bool? reusePort,
  int? ttl,
}) {
  return RawDatagramSocket.bind(
    _mdnsDatagramBindHost(host),
    port,
    reuseAddress: reuseAddress ?? true,
    reusePort:
        !(Platform.isWindows || Platform.isAndroid) && (reusePort ?? true),
    ttl: ttl ?? 255,
  );
}

Iterable<NetworkInterface> filterMdnsInterfaces(
  Iterable<NetworkInterface> interfaces,
  InternetAddressType type, {
  bool isWindows = false,
}) {
  return interfaces
      .where((interface) {
        final addresses = interface.addresses.where((address) {
          if (address.type != type) {
            return false;
          }
          if (address.isLoopback) {
            return false;
          }
          if (isWindows && address.isLinkLocal) {
            return false;
          }
          return true;
        });

        return addresses.isNotEmpty;
      })
      .toList(growable: false);
}

Future<Iterable<NetworkInterface>> _mdnsNetworkInterfacesFactory(
  InternetAddressType type,
) async {
  final interfaces = await NetworkInterface.list(
    includeLinkLocal: !Platform.isWindows,
    type: type,
  );
  return filterMdnsInterfaces(interfaces, type, isWindows: Platform.isWindows);
}

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
  Future<List<ActiveHost>> findingMdnsWithAddress(String serviceType) async {
    final MDnsClient client = MDnsClient(
      rawDatagramSocketFactory: _mdnsRawDatagramSocketFactory,
    );

    final List<ActiveHost> listOfActiveHost = [];
    final Completer<void> completer = Completer<void>();

    runZonedGuarded(
      () async {
        try {
          await client.start(
            listenAddress: InternetAddress.anyIPv4,
            interfacesFactory: _mdnsNetworkInterfacesFactory,
          );

          await for (final PtrResourceRecord ptr
              in client.lookup<PtrResourceRecord>(
                ResourceRecordQuery.serverPointer(serviceType),
              )) {
            await for (final SrvResourceRecord srv
                in client.lookup<SrvResourceRecord>(
                  ResourceRecordQuery.service(ptr.domainName),
                )) {
              await for (final TxtResourceRecord txtRecords
                  in client.lookup<TxtResourceRecord>(
                    ResourceRecordQuery.text(ptr.domainName),
                  )) {
                listOfActiveHost.addAll(
                  await findAllActiveHostForSrv(
                    addressType: InternetAddress.anyIPv4,
                    client: client,
                    ptr: ptr,
                    srv: srv,
                    txt: txtRecords,
                  ),
                );
                listOfActiveHost.addAll(
                  await findAllActiveHostForSrv(
                    addressType: InternetAddress.anyIPv6,
                    client: client,
                    ptr: ptr,
                    srv: srv,
                    txt: txtRecords,
                  ),
                );
              }
            }
          }
        } catch (e) {
          logger.severe(
            'Error finding mdns devices for serviceType $serviceType: $e',
          );
        } finally {
          client.stop();
          if (!completer.isCompleted) completer.complete();
        }
      },
      (Object error, StackTrace stack) {
        logger.severe(
          'Unhandled async error in findingMdnsWithAddress for $serviceType: $error',
        );
        client.stop();
        if (!completer.isCompleted) completer.complete();
      },
    );

    await completer.future;
    return listOfActiveHost;
  }

  @override
  Future<List<ActiveHost>> findAllActiveHostForSrv({
    required InternetAddress addressType,
    required MDnsClient client,
    required PtrResourceRecord ptr,
    required SrvResourceRecord srv,
    required TxtResourceRecord txt,
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
          internetAddress: normalizeInternetAddress(ip.address),
          ptr: ptr,
          srv: srv,
          txt: txt,
        );

        listOfActiveHost.add(activeHost);
      }
    } catch (e) {
      logger.severe(
        'Error finding ip of mdns record ${ptr.name} srv target ${srv.target}, will add it with ip 0.0.0.0\n$e',
      );
      final ActiveHost activeHost = convertSrvToHostName(
        internetAddress: InternetAddress('0.0.0.0'),
        srv: srv,
        ptr: ptr,
        txt: txt,
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
    required TxtResourceRecord txt,
  }) {
    final MdnsInfo mdnsInfo = MdnsInfo(
      srvResourceRecord: srv,
      ptrResourceRecord: ptr,
      txtResourceRecord: txt,
    );
    return ActiveHost(internetAddress: internetAddress, mdnsInfoVar: mdnsInfo);
  }
}
