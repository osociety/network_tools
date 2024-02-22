import 'package:network_tools/src/models/active_host.dart';
import 'package:network_tools/src/models/callbacks.dart';
import 'package:network_tools/src/models/sendable_active_host.dart';

/// Scans for all hosts in a subnet.
abstract class HostScannerService {
  HostScannerService() {
    _instance = this;
  }

  static late HostScannerService _instance;

  static HostScannerService get instance => _instance;

  /// Devices scan will start from this integer Id
  static const int defaultFirstHostId = 1;

  /// Devices scan will stop at this integer id
  static const int defaultLastHostId = 254;

  Stream<ActiveHost> getAllPingableDevices(
    String subnet, {
    int firstHostId = defaultFirstHostId,
    int lastHostId = defaultLastHostId,
    int timeoutInSeconds = 1,
    ProgressCallback? progressCallback,
    bool resultsInAddressAscendingOrder = true,
  });

  Stream<SendableActiveHost> getAllSendablePingableDevices(
    String subnet, {
    int firstHostId = defaultFirstHostId,
    int lastHostId = defaultLastHostId,
    int timeoutInSeconds = 1,
    ProgressCallback? progressCallback,
    bool resultsInAddressAscendingOrder = true,
  });

  int validateAndGetLastValidSubnet(
    String subnet,
    int firstHostId,
    int lastHostId,
  );

  Stream<ActiveHost> getAllPingableDevicesAsync(
    String subnet, {
    int firstHostId = defaultFirstHostId,
    int lastHostId = defaultLastHostId,
    int timeoutInSeconds = 1,
    ProgressCallback? progressCallback,
    bool resultsInAddressAscendingOrder = true,
  });

  Stream<ActiveHost> scanDevicesForSinglePort(
    String subnet,
    int port, {
    int firstHostId = defaultFirstHostId,
    int lastHostId = defaultLastHostId,
    Duration timeout = const Duration(milliseconds: 2000),
    ProgressCallback? progressCallback,
    bool resultsInAddressAscendingOrder = true,
  });
}
