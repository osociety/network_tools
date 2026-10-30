import 'package:network_tools/src/models/active_host.dart';
import 'package:network_tools/src/models/callbacks.dart';
import 'package:network_tools/src/models/sendable_active_host.dart';
import 'package:network_tools/src/services/port_scanner_service.dart';

/// Scans for all hosts in a subnet.
///
/// On Linux, macOS and Windows discovery is ARP-first: the scanner primes the
/// neighbour cache and reads the numeric ARP table once, which is much faster
/// than pinging every address and also finds hosts that ignore ICMP. Mobile
/// platforms, non-local subnets and loopback use an ICMP sweep instead.
///
/// ARP does not carry host names. Name lookups run concurrently for the hosts
/// that were found and are attached to [ActiveHost.hostName]; a network
/// without reverse DNS simply yields no names.
abstract class HostScannerService {
  HostScannerService() {
    _instance = this;
  }

  static late HostScannerService _instance;

  /// The registered scanner implementation.
  ///
  /// Available after the package is configured, usually by calling
  /// `configureNetworkTools` from `main`.
  static HostScannerService get instance => _instance;

  /// Devices scan will start from this integer Id
  static const int defaultFirstHostId = 1;

  /// Devices scan will stop at this integer id
  static const int defaultLastHostId = 254;

  /// Streams every reachable device in [subnet] (e.g. `192.168.1`).
  ///
  /// [hostIds] limits the scan to specific host ids and takes precedence over
  /// the [firstHostId]..[lastHostId] range. [timeoutInSeconds] is the ICMP
  /// timeout used to confirm hosts found through the neighbor table and for
  /// the sweep fallback.
  ///
  /// Results are emitted in ascending address order unless
  /// [resultsInAddressAscendingOrder] is `false`, which delivers each host as
  /// soon as it is confirmed. [progressCallback] receives values up to 100;
  /// it is not called in unordered mode. Cancel the subscription when the
  /// stream is no longer needed.
  ///
  /// Host details ([ActiveHost.hostName], [ActiveHost.deviceName],
  /// [ActiveHost.getMacAddress], [ActiveHost.vendor]) are resolved lazily, so
  /// they do not delay discovery. Discovery may already have resolved the
  /// host name; otherwise the first access performs the lookup.
  Stream<ActiveHost> getAllPingableDevices(
    String subnet, {
    int firstHostId = defaultFirstHostId,
    int lastHostId = defaultLastHostId,
    List<int> hostIds = const [],
    int timeoutInSeconds = 1,
    ProgressCallback? progressCallback,
    bool resultsInAddressAscendingOrder = true,
  });

  /// Same as [getAllPingableDevices], but emits sendable objects that can cross
  /// an isolate boundary. MAC addresses and host names discovered during the
  /// scan are carried on [SendableActiveHost].
  Stream<SendableActiveHost> getAllSendablePingableDevices(
    String subnet, {
    int firstHostId = defaultFirstHostId,
    int lastHostId = defaultLastHostId,
    List<int> hostIds = const [],
    int timeoutInSeconds = 1,
    ProgressCallback? progressCallback,
    bool resultsInAddressAscendingOrder = true,
  });

  /// Validates the requested range and returns the last host id to scan.
  ///
  /// The maximum host id depends on the subnet class. Throws a [String] when
  /// the range is invalid or outside the supported host ids.
  int validateAndGetLastValidSubnet(
    String subnet,
    int firstHostId,
    int lastHostId,
  );

  /// Same as [getAllPingableDevices], but runs the entire scan in a separate
  /// isolate so the calling isolate (usually the UI) stays responsive.
  ///
  /// The first result arrives after the isolate starts and the neighbor table
  /// is read; the vendor table is not built there because lookups happen when
  /// host details are accessed in the calling isolate.
  Stream<ActiveHost> getAllPingableDevicesAsync(
    String subnet, {
    int firstHostId = defaultFirstHostId,
    int lastHostId = defaultLastHostId,
    List<int> hostIds = const [],
    int timeoutInSeconds = 1,
    ProgressCallback? progressCallback,
    bool resultsInAddressAscendingOrder = true,
  });

  /// Streams the devices in [subnet] that have [port] open.
  ///
  /// The ICMP host scan runs first, then a bounded socket pool (see
  /// [maxConcurrency]) connects to [port] on each device. Results follow the
  /// same ordering and progress rules as [getAllPingableDevices].
  Stream<ActiveHost> scanDevicesForSinglePort(
    String subnet,
    int port, {
    int firstHostId = defaultFirstHostId,
    int lastHostId = defaultLastHostId,
    Duration timeout = const Duration(milliseconds: 2000),
    ProgressCallback? progressCallback,
    bool resultsInAddressAscendingOrder = true,
    int maxConcurrency = PortScannerService.defaultMaxConcurrency,
  });
}
