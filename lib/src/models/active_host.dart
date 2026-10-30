import 'dart:async';

import 'package:dart_ping/dart_ping.dart';
import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/injection.dart';
import 'package:network_tools/src/network_tools_utils.dart';
import 'package:network_tools/src/repository/repository.dart';
import 'package:universal_io/io.dart';

/// A device found on the network.
///
/// Host details are resolved lazily and cached: [hostName], [deviceName],
/// [mdnsInfo], [arpData], [vendor] and [getMacAddress] only perform their
/// lookup when first accessed, unless discovery already filled them in.
/// Implements [Comparable] ordering by host id ascending.
class ActiveHost {
  ActiveHost({
    required this.internetAddress,
    this.openPorts = const [],
    String? macAddress,
    PingResponse? pingData,
    MdnsInfo? mdnsInfoVar,
    String? hostName,
  }) {
    _macAddress = macAddress;
    final String tempAddress = internetAddress.address;

    if (tempAddress.contains('.')) {
      hostId = tempAddress.substring(
        tempAddress.lastIndexOf('.') + 1,
        tempAddress.length,
      );
    } else if (tempAddress.contains(':')) {
      hostId = tempAddress.substring(
        tempAddress.lastIndexOf(':') + 1,
        tempAddress.length,
      );
    } else {
      hostId = '-1';
    }
    _pingData = pingData;

    // Resolution (reverse DNS, ARP and vendor lookups) is intentionally lazy so
    // that discovery returns hosts as fast as the network scan allows. The
    // futures below are started on first access.
    weirdHostName = internetAddress.host;

    if (_isUsefulName(hostName)) {
      _hostName = Future.value(hostName);
    }

    if (mdnsInfoVar != null) {
      _mdnsInfo = Future.value(mdnsInfoVar);
    }
  }
  factory ActiveHost.buildWithAddress({
    required String address,
    String? macAddress,
    List<OpenPort> openPorts = const [],
    PingResponse? pingData,
    MdnsInfo? mdnsInfo,
  }) {
    final InternetAddress? internetAddressTemp = InternetAddress.tryParse(
      address,
    );
    if (internetAddressTemp == null) {
      throw 'Cant parse address $address to InternetAddress';
    }
    return ActiveHost(
      internetAddress: internetAddressTemp,
      macAddress: macAddress,
      openPorts: openPorts,
      pingData: pingData,
      mdnsInfoVar: mdnsInfo,
    );
  }

  factory ActiveHost.fromSendableActiveHost({
    required SendableActiveHost sendableActiveHost,
    String? macAddress,
    MdnsInfo? mdnsInfo,
  }) {
    final InternetAddress? internetAddressTemp = InternetAddress.tryParse(
      sendableActiveHost.address,
    );
    if (internetAddressTemp == null) {
      throw 'Cant parse address ${sendableActiveHost.address} to InternetAddress';
    }
    return ActiveHost(
      internetAddress: internetAddressTemp,
      macAddress: macAddress ?? sendableActiveHost.macAddress,
      openPorts: sendableActiveHost.openPorts,
      pingData: sendableActiveHost.pingData,
      mdnsInfoVar: mdnsInfo,
      hostName: sendableActiveHost.hostName,
    );
  }

  static const generic = 'Generic Device';

  InternetAddress internetAddress;

  /// The device specific number in the ip address. In IPv4 numbers after the
  /// last dot, in IPv6 the numbers after the last colon
  late String hostId;

  Future<String?>? _hostName;

  /// Host name of the device, resolved through reverse DNS (PTR).
  ///
  /// The lookup starts lazily on first access with a short timeout and is
  /// cached. Discovery may already have resolved it, in which case this
  /// completes immediately. Returns null when the network has no reverse DNS
  /// or the address has no PTR record, and never returns the bare address.
  ///
  /// Not to be confused with [deviceName], which is a display name and does not
  /// follow any internet protocol property.
  Future<String?> get hostName => _hostName ??= setHostInfo();
  late String weirdHostName;
  late final PingResponse? _pingData;

  Future<MdnsInfo?>? _mdnsInfo;

  /// mDNS information for this device, when discovery found any.
  ///
  /// Resolved lazily on first access; currently mDNS results come from the
  /// mDNS scanner and are null for hosts found by the host scanner.
  Future<MdnsInfo?> get mdnsInfo => _mdnsInfo ??= setMdnsInfo();

  Future<ARPData?>? _arpData;

  /// The neighbor table entry for this address, or null when unavailable.
  ///
  /// Only supported on Linux, macOS and Windows. Resolved lazily from the ARP
  /// repository unless discovery already attached the MAC address.
  Future<ARPData?> get arpData => _arpData ??= setARPData();

  Future<Vendor?>? _vendor;

  /// The vendor that owns this device's MAC prefix, or null when the MAC
  /// address or vendor table is unavailable. Resolved lazily.
  Future<Vendor?> get vendor => _vendor ??= setVendor();

  /// MAC address of the device, or null when it cannot be determined.
  ///
  /// Hosts found through the neighbor table already carry their MAC address,
  /// so this completes without another read on Linux, macOS and Windows.
  String? _macAddress;
  Future<String?> getMacAddress() async =>
      _macAddress ?? (await arpData)?.macAddress;

  /// List of all the open port of this device
  List<OpenPort> openPorts;

  Future<String>? _deviceName;

  /// A human-readable name for the device, suitable for display.
  ///
  /// Tries [hostName], then the mDNS name, then the name recorded in the
  /// neighbor table, and finally falls back to [generic]. Resolved lazily and
  /// cached, so this may complete immediately when discovery already resolved
  /// the name and otherwise performs the lookup on first access.
  Future<String> get deviceName => _deviceName ??= setDeviceName();

  /// The ICMP response recorded during discovery, or null when the host was
  /// found through the neighbor table without answering ping.
  PingResponse? get pingData => _pingData;

  /// Round-trip time of the discovery ping, or null without [pingData].
  Duration? get responseTime {
    final event = _pingData;
    if (event is PingResponse) return event.time;
    return null;
  }

  /// The device's IPv4 or IPv6 address as a string.
  String get address => internetAddress.address;

  static PingResponse? getPingData(String host) {
    const int timeoutInSeconds = 1;
    PingResponse? tempPingData;

    Ping(
      host,
      count: 1,
      timeout: timeoutInSeconds,
      forceCodepage: Platform.isWindows,
    ).stream.listen((Object? event) {
      final PingResponse? response = _extractPingResponse(event);
      if (response != null && response.time != null) {
        tempPingData = response;
      }
    });
    return tempPingData;
  }

  static PingResponse? _extractPingResponse(Object? event) {
    if (event is PingResponse) {
      return event;
    }
    if (event == null) {
      return null;
    }

    // dart_ping changed its stream payload type across versions.
    // Some versions emit PingSummary or other payloads instead of a response.
    try {
      final dynamic dynamicEvent = event;
      // ignore: avoid_dynamic_calls
      final Object? response = dynamicEvent.response;
      return response is PingResponse ? response : null;
    } catch (error) {
      return null;
    }
  }

  /// Maximum time to wait for a reverse DNS answer before giving up.
  static const Duration reverseLookupTimeout = Duration(seconds: 2);

  /// Try to find the host name of this device, if not exist host name will
  /// stay null
  Future<String?> setHostInfo() async {
    // For some reason when internetAddress.host get called before the reverse
    // there is weired value
    weirdHostName = internetAddress.host;

    // In the future if mdnsInfo is null it will execute a search
    // Currently the functionality is missing in dart multicast_dns package
    // https://github.com/flutter/flutter/issues/96755

    try {
      final InternetAddress resolved = await internetAddress.reverse().timeout(
        reverseLookupTimeout,
      );
      final String host = resolved.host;
      // Some platforms return the IP itself when no PTR record exists.
      if (host.isEmpty || host == address) {
        return null;
      }
      internetAddress = resolved;
      return host;
    } on TimeoutException {
      logger.fine('Reverse DNS lookup timed out for $address');
    } catch (e) {
      if (e is SocketException &&
          e.osError != null &&
          (e.osError!.message == 'Name or service not known')) {
        // Some devices does not have host name and the reverse search will just
        // throw exception.
        // We don't need to print this crash as it is by design.
      } else {
        logger.severe('Exception here: $e');
      }
    }
    return null;
  }

  /// Resolves every lazy detail of this host: neighbor table entry, device
  /// name, mDNS info and host name.
  ///
  /// Prefer awaiting the individual getters when only some details are needed.
  Future<void> resolveInfo() async {
    await arpData;
    // await vendor;
    await deviceName;
    await mdnsInfo;
    await hostName;
  }

  Future<ARPData?> setARPData() {
    return getIt<Repository<ARPData>>().entryFor(address);
  }

  Future<Vendor?> setVendor() async {
    final String? macAddress = await getMacAddress();

    return macAddress == null
        ? null
        : await getIt<Repository<Vendor>>().entryFor(macAddress);
  }

  /// Try to find the mdns name of this device, if not exist mdns name will
  /// be null
  /// TODO: search mdns name for each device
  Future<MdnsInfo?> setMdnsInfo() async {
    return null;
  }

  /// Set some kind of device name.
  /// Will try couple of names, if all are null will just return [generic]
  Future<String> setDeviceName() async {
    final String? hostNameTemp = await hostName;
    if (_isUsefulName(hostNameTemp)) {
      return hostNameTemp!;
    }
    final MdnsInfo? mdnsTemp = await mdnsInfo;
    final String? mdnsName = mdnsTemp?.getOnlyTheStartOfMdnsName();
    if (_isUsefulName(mdnsName)) {
      return mdnsName!;
    }
    // ARP tables on Linux and macOS usually contain the peer host name.
    final String? arpHostName = (await arpData)?.hostname;
    if (_isUsefulName(arpHostName)) {
      return arpHostName!;
    }
    return generic;
  }

  bool _isUsefulName(String? name) {
    if (name == null || name.isEmpty || name == '?') {
      return false;
    }
    return name != address;
  }

  @override
  int get hashCode => address.hashCode;

  @override
  bool operator ==(Object o) => o is ActiveHost && address == o.address;

  int compareTo(ActiveHost other) {
    return hostId.compareTo(other.hostId);
  }

  @override
  String toString() {
    return 'Address: $address, HostId: $hostId, Time: ${responseTime?.inMilliseconds}ms, port: ${openPorts.join(",")}';
  }

  Future<String> toStringFull() async {
    return 'Address: $address, MAC: ${(await arpData)?.macAddress}, HostId: $hostId, Vendor: ${(await vendor)?.vendorName} Time: ${responseTime?.inMilliseconds}ms, DeviceName: ${await deviceName}, HostName: ${await hostName}, MdnsInfo: ${await mdnsInfo}';
  }
}
