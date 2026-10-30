import 'package:dart_ping/dart_ping.dart';

import 'package:network_tools/network_tools.dart';

/// A discovered host in a form that can be sent across an isolate boundary.
///
/// Host scanners emit these so the scan can run in a separate isolate and the
/// calling isolate can wrap them in [ActiveHost].
class SendableActiveHost {
  SendableActiveHost(
    this.address, {
    this.pingData,
    this.openPorts = const [],
    this.macAddress,
    this.hostName,
  });

  /// The host's IPv4 or IPv6 address.
  final String address;

  /// The ICMP response recorded while confirming the host, or null when the
  /// host was found through the neighbor table without answering ping.
  final PingResponse? pingData;

  /// Ports found open on this host.
  List<OpenPort> openPorts;

  /// MAC address read from the neighbor table during discovery, when available.
  final String? macAddress;

  /// Host name resolved during discovery so consumers do not have to wait for
  /// another lookup.
  final String? hostName;
}
