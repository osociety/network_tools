import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:dart_ping/dart_ping.dart';
import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/concurrency.dart';
import 'package:network_tools/src/device_info/arp_table_helper.dart';
import 'package:network_tools/src/injection.dart';
import 'package:network_tools/src/network_tools_utils.dart';
import 'package:network_tools/src/repository/repository.dart';
import 'package:universal_io/io.dart';

/// Scans for all hosts in a subnet.
class HostScannerServiceImpl extends HostScannerService {
  HostScannerServiceImpl({
    ARPTableHelper? arpTableHelper,
    Future<bool> Function(String subnet)? isLocalSubnet,
  }) : _arpTableHelper = arpTableHelper ?? ARPTableHelper(),
       _isLocalSubnet = isLocalSubnet ?? _defaultIsLocalSubnet;

  final ARPTableHelper _arpTableHelper;
  final Future<bool> Function(String subnet) _isLocalSubnet;

  /// Budget for the host name lookup that runs during discovery.
  ///
  /// Short on purpose: networks without working reverse DNS make every lookup
  /// wait for the full budget before a host is emitted. [ActiveHost.hostName]
  /// retries lazily with a longer timeout, so a slow lookup here never removes
  /// the name from the result.
  static const Duration preferredHostNameTimeout = Duration(milliseconds: 250);

  /// Upper bound for concurrent per-host verification and name lookups.
  static const int hostLookupConcurrency = 64;

  static Future<bool> _defaultIsLocalSubnet(String subnet) async {
    // Loopback has no ARP table; pinging it is cheaper and always works.
    if (subnet.startsWith('127.')) {
      return false;
    }
    try {
      final List<NetworkInterface> interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: true,
      );
      for (final NetworkInterface interface in interfaces) {
        for (final InternetAddress address in interface.addresses) {
          if (address.address.startsWith('$subnet.')) {
            return true;
          }
        }
      }
    } catch (error, stackTrace) {
      logger.fine(
        'Unable to inspect local interfaces for $subnet: $error',
        error,
        stackTrace,
      );
    }
    return false;
  }

  /// Scans for all hosts in a particular subnet (e.g., 192.168.1.0/24)
  /// Set maxHost to higher value if you are not getting results.
  /// It won't firstHostId again unless previous scan is completed due to heavy
  /// resource consumption.
  /// Use hostIds to limit subnet scan to hosts given.
  /// [resultsInAddressAscendingOrder] = false will return results faster but not in
  /// ascending order and without [progressCallback].
  @override
  Stream<ActiveHost> getAllPingableDevices(
    String subnet, {
    int firstHostId = HostScannerService.defaultFirstHostId,
    int lastHostId = HostScannerService.defaultLastHostId,
    List<int> hostIds = const [],
    int timeoutInSeconds = 1,
    ProgressCallback? progressCallback,
    bool resultsInAddressAscendingOrder = true,
  }) async* {
    final stream = getAllSendablePingableDevices(
      subnet,
      firstHostId: firstHostId,
      lastHostId: lastHostId,
      hostIds: hostIds,
      timeoutInSeconds: timeoutInSeconds,
      progressCallback: progressCallback,
      resultsInAddressAscendingOrder: resultsInAddressAscendingOrder,
    );
    await for (final sendableActiveHost in stream) {
      // Host details (host name, ARP, vendor) resolve lazily, so they do not
      // delay discovery. Awaiting each host's resolveInfo() here used to
      // serialize a reverse DNS lookup per device.
      yield ActiveHost.fromSendableActiveHost(
        sendableActiveHost: sendableActiveHost,
      );
    }
  }

  /// Same as [getAllPingableDevices] but can be called or run inside isolate.
  @override
  Stream<SendableActiveHost> getAllSendablePingableDevices(
    String subnet, {
    int firstHostId = HostScannerService.defaultFirstHostId,
    int lastHostId = HostScannerService.defaultLastHostId,
    List<int> hostIds = const [],
    int timeoutInSeconds = 1,
    ProgressCallback? progressCallback,
    bool resultsInAddressAscendingOrder = true,
  }) async* {
    final int lastValidSubnet = validateAndGetLastValidSubnet(
      subnet,
      firstHostId,
      lastHostId,
    );
    final List<int> idsToScan = <int>[
      for (int i = firstHostId; i <= lastValidSubnet; i++)
        if (hostIds.isEmpty || hostIds.contains(i)) i,
    ];
    if (idsToScan.isEmpty) {
      return;
    }

    // Every live host on a directly connected IPv4 subnet has to answer ARP,
    // so priming the kernel cache and reading it once finds hosts in
    // milliseconds. Other cases (mobile, remote subnets, loopback) fall back
    // to the ICMP sweep.
    if (_arpTableHelper.isARPSupported && await _isLocalSubnet(subnet)) {
      final List<ARPData> table = await _readNeighborTable(subnet, idsToScan);
      if (table.isNotEmpty) {
        yield* _yieldARPResults(
          subnet: subnet,
          idsToScan: idsToScan,
          table: table,
          firstHostId: firstHostId,
          lastValidSubnet: lastValidSubnet,
          timeoutInSeconds: timeoutInSeconds,
          progressCallback: progressCallback,
          resultsInAddressAscendingOrder: resultsInAddressAscendingOrder,
        );
        return;
      }
      logger.fine('ARP table has no entries for $subnet, using ping sweep');
    }

    yield* _yieldPingResults(
      subnet: subnet,
      idsToScan: idsToScan,
      firstHostId: firstHostId,
      lastValidSubnet: lastValidSubnet,
      timeoutInSeconds: timeoutInSeconds,
      progressCallback: progressCallback,
      resultsInAddressAscendingOrder: resultsInAddressAscendingOrder,
    );
  }

  /// Host ids in [idsToScan] that belong to this machine.
  ///
  /// Linux and Windows do not list the local address in their own neighbor
  /// table, so ARP discovery would otherwise drop the device the scan runs on.
  Future<Set<int>> _localHostIds(String subnet, Iterable<int> idsToScan) async {
    final Set<int> requested = idsToScan.toSet();
    final Set<int> localIds = <int>{};
    try {
      final List<NetworkInterface> interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: true,
        includeLoopback: true,
      );
      for (final NetworkInterface interface in interfaces) {
        for (final InternetAddress address in interface.addresses) {
          if (!address.address.startsWith('$subnet.')) {
            continue;
          }
          final int? id = int.tryParse(address.address.split('.').last);
          if (id != null && requested.contains(id)) {
            localIds.add(id);
          }
        }
      }
    } catch (error, stackTrace) {
      logger.fine(
        'Unable to inspect local addresses for $subnet: $error',
        error,
        stackTrace,
      );
    }
    return localIds;
  }

  /// Primes the neighbor cache for [idsToScan] and returns the matching rows.
  Future<List<ARPData>> _readNeighborTable(
    String subnet,
    List<int> idsToScan,
  ) async {
    try {
      await _arpTableHelper.primeARPCache(<String>[
        for (final int id in idsToScan) '$subnet.$id',
      ]);
      return await _arpTableHelper.buildNumericTable();
    } catch (error, stackTrace) {
      logger.warning(
        'Failed to read the ARP table, falling back to ping: $error',
        error,
        stackTrace,
      );
      return const <ARPData>[];
    }
  }

  Stream<SendableActiveHost> _yieldARPResults({
    required String subnet,
    required List<int> idsToScan,
    required List<ARPData> table,
    required int firstHostId,
    required int lastValidSubnet,
    required int timeoutInSeconds,
    required bool resultsInAddressAscendingOrder,
    ProgressCallback? progressCallback,
  }) async* {
    final Map<String, ARPData> byAddress = <String, ARPData>{
      for (final ARPData entry in table) entry.iPAddress: entry,
    };
    // A machine is never listed in its own Linux and Windows neighbor table,
    // so add it explicitly when it falls inside the requested range.
    final Set<int> localIds = await _localHostIds(subnet, idsToScan);
    // Keep the requested order; hostIds are not necessarily sorted.
    final List<int> candidates = <int>[
      for (final int id in idsToScan)
        if (byAddress.containsKey('$subnet.$id') || localIds.contains(id)) id,
    ];
    if (candidates.isEmpty) {
      return;
    }

    final Stream<ConcurrentResult<SendableActiveHost?>> results =
        mapConcurrently<int, SendableActiveHost?>(candidates, (int id) {
          final String host = '$subnet.$id';
          final ARPData? arpData = byAddress[host];
          if (arpData != null) {
            return _verifyARPHost(host, arpData, timeoutInSeconds);
          }
          return getHostFromPing(
            activeHostsController: null,
            host: host,
            timeoutInSeconds: timeoutInSeconds,
          );
        }, maxConcurrency: hostLookupConcurrency);

    if (!resultsInAddressAscendingOrder) {
      await for (final ConcurrentResult<SendableActiveHost?> result
          in results) {
        final SendableActiveHost? host = result.value;
        if (host != null) {
          yield host;
        }
      }
      return;
    }

    // Verification finishes out of order; buffer until every earlier host has
    // been emitted so the ascending-order contract is preserved.
    final Map<int, SendableActiveHost?> pending = <int, SendableActiveHost?>{};
    int nextIndex = 0;
    await for (final ConcurrentResult<SendableActiveHost?> result in results) {
      pending[result.index] = result.value;
      while (pending.containsKey(nextIndex)) {
        final SendableActiveHost? host = pending.remove(nextIndex);
        final int id = candidates[nextIndex];
        nextIndex++;
        progressCallback?.call(_progressFor(id, firstHostId, lastValidSubnet));
        if (host != null) {
          yield host;
        }
      }
    }
    // Priming probed the whole range, so discovery is complete here.
    progressCallback?.call(100);
  }

  /// Confirms an ARP-discovered host and attaches its resolved name.
  ///
  /// The ping only fills [SendableActiveHost.pingData]; the host is returned
  /// even when it ignores ICMP because a fresh neighbor entry proves that it
  /// is reachable on the local network.
  Future<SendableActiveHost> _verifyARPHost(
    String host,
    ARPData arpData,
    int timeoutInSeconds,
  ) async {
    final Future<PingResponse?> pingFuture = _pingHost(host, timeoutInSeconds);
    final Future<String?> nameFuture = _resolveHostName(host);
    final PingResponse? pingData = await pingFuture;
    final String? hostName = await nameFuture;
    logger.fine('ARP host $host found (name: $hostName)');
    return SendableActiveHost(
      host,
      pingData: pingData,
      macAddress: arpData.macAddress,
      hostName: hostName,
    );
  }

  Stream<SendableActiveHost> _yieldPingResults({
    required String subnet,
    required List<int> idsToScan,
    required int firstHostId,
    required int lastValidSubnet,
    required int timeoutInSeconds,
    required bool resultsInAddressAscendingOrder,
    ProgressCallback? progressCallback,
  }) async* {
    // The controller is only needed for unordered delivery; creating it in
    // ordered mode would buffer results that nobody listens to.
    final StreamController<SendableActiveHost>? activeHostsController =
        resultsInAddressAscendingOrder
        ? null
        : StreamController<SendableActiveHost>();

    final List<Future<SendableActiveHost?>> activeHostsFuture =
        <Future<SendableActiveHost?>>[
          for (final int id in idsToScan)
            getHostFromPing(
              activeHostsController: activeHostsController,
              host: '$subnet.$id',
              timeoutInSeconds: timeoutInSeconds,
            ),
        ];

    if (!resultsInAddressAscendingOrder) {
      // Close the controller once every ping future has completed, otherwise
      // consumers iterating this stream would never see it finish.
      unawaited(
        Future.wait(activeHostsFuture).then(
          (_) => activeHostsController?.close(),
          onError: (Object _) => activeHostsController?.close(),
        ),
      );
      yield* activeHostsController!.stream;
      return;
    }

    int i = 0;
    for (final Future<SendableActiveHost?> host in activeHostsFuture) {
      final SendableActiveHost? tempHost = await host;
      progressCallback?.call(
        _progressFor(idsToScan[i], firstHostId, lastValidSubnet),
      );
      i++;
      if (tempHost == null) {
        continue;
      }
      yield tempHost;
    }
  }

  double _progressFor(int hostId, int firstHostId, int lastValidSubnet) {
    final int span = lastValidSubnet - firstHostId;
    if (span <= 0) {
      return 100;
    }
    return (hostId - firstHostId) * 100 / span;
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

  Future<PingResponse?> _pingHost(String host, int timeoutInSeconds) async {
    try {
      await for (final Object? event in Ping(
        host,
        count: 1,
        timeout: timeoutInSeconds,
        forceCodepage: Platform.isWindows,
      ).stream) {
        final PingResponse? pingResponse = _extractPingResponse(event);
        if (pingResponse != null && pingResponse.time != null) {
          return pingResponse;
        }
      }
    } catch (error, stackTrace) {
      // A failing ping for one host must not abort the whole subnet scan.
      logger.warning("Ping failed for $host: $error", error, stackTrace);
    }
    return null;
  }

  /// Resolves a host name while discovery is running.
  ///
  /// This lookup has a short budget so it cannot stall the scan. A host that
  /// does not answer in time still gets another chance through
  /// [ActiveHost.hostName], which uses a longer lazy timeout.
  Future<String?> _resolveHostName(String host) async {
    try {
      final InternetAddress resolved = await InternetAddress(
        host,
      ).reverse().timeout(preferredHostNameTimeout);
      final String name = resolved.host;
      if (name.isEmpty || name == host) {
        return null;
      }
      return name;
    } on TimeoutException {
      logger.fine('Host name lookup timed out for $host');
    } catch (error) {
      logger.fine('Host name lookup failed for $host: $error');
    }
    return null;
  }

  Future<SendableActiveHost?> getHostFromPing({
    required String host,
    required StreamController<SendableActiveHost>? activeHostsController,
    int timeoutInSeconds = 1,
  }) async {
    SendableActiveHost? tempSendableActivateHost;

    final PingResponse? pingResponse = await _pingHost(host, timeoutInSeconds);
    if (pingResponse != null) {
      // Check if ping succeeded
      logger.fine("Pingable device found: $host");
      tempSendableActivateHost = SendableActiveHost(
        host,
        pingData: pingResponse,
      );
    } else {
      logger.fine("Non pingable device found: $host");
      // Check if it's there in arp table
      try {
        final data = await getIt<Repository<ARPData>>().entryFor(host);
        if (data != null) {
          logger.fine("Successfully fetched arp entry for $host as $data");
          tempSendableActivateHost = SendableActiveHost(
            host,
            macAddress: data.macAddress,
          );
        } else {
          logger.fine("Problem in fetching arp entry for $host");
        }
      } catch (error, stackTrace) {
        logger.warning(
          "Failed to fetch arp entry for $host: $error",
          error,
          stackTrace,
        );
      }
    }

    if (tempSendableActivateHost != null) {
      logger.fine("Successfully added to result $host");
      if (activeHostsController != null && !activeHostsController.isClosed) {
        activeHostsController.add(tempSendableActivateHost);
      }
    }

    return tempSendableActivateHost;
  }

  @override
  int validateAndGetLastValidSubnet(
    String subnet,
    int firstHostId,
    int lastHostId,
  ) {
    final int maxEnd = maxHost;
    if (firstHostId > lastHostId ||
        firstHostId < HostScannerService.defaultFirstHostId ||
        lastHostId < HostScannerService.defaultFirstHostId ||
        firstHostId > maxEnd ||
        lastHostId > maxEnd) {
      throw 'Invalid subnet range or firstHostId < lastHostId is not true';
    }
    return min(lastHostId, maxEnd);
  }

  /// Works same as [getAllPingableDevices] but does everything inside
  /// isolate out of the box.
  @override
  Stream<ActiveHost> getAllPingableDevicesAsync(
    String subnet, {
    int firstHostId = HostScannerService.defaultFirstHostId,
    int lastHostId = HostScannerService.defaultLastHostId,
    List<int> hostIds = const [],
    int timeoutInSeconds = 1,
    ProgressCallback? progressCallback,
    bool resultsInAddressAscendingOrder = true,
  }) async* {
    final int lastValidSubnet = validateAndGetLastValidSubnet(
      subnet,
      firstHostId,
      lastHostId,
    );
    // The whole scan happens in a single isolate. Previously the range was
    // split into 51-host chunks, which meant spawning up to five isolates and
    // running configureNetworkTools (database setup) in each of them.
    logger.fine('Scanning from $firstHostId to $lastValidSubnet');

    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _startSearchingDevices,
      receivePort.sendPort,
    );

    try {
      await for (final message in receivePort) {
        if (message is SendPort) {
          message.send(<String>[
            subnet,
            firstHostId.toString(),
            lastValidSubnet.toString(),
            timeoutInSeconds.toString(),
            resultsInAddressAscendingOrder.toString(),
            dbDirectory,
            enableDebugging.toString(),
            hostIds.join(','),
          ]);
        } else if (message is SendableActiveHost) {
          final activeHostFound = ActiveHost.fromSendableActiveHost(
            sendableActiveHost: message,
          );
          final j = int.tryParse(activeHostFound.hostId) ?? firstHostId;
          progressCallback?.call(_progressFor(j, firstHostId, lastValidSubnet));
          yield activeHostFound;
        } else if (message is String && message == 'Done') {
          // The isolate sends one message per host, so the scan can finish on
          // host ids below 254 without the last host reporting 100.
          progressCallback?.call(100);
          break;
        }
      }
    } finally {
      // Also runs when the consumer cancels the stream early.
      isolate.kill();
      receivePort.close();
    }
  }

  /// Will search devices in the network inside new isolate
  @pragma('vm:entry-point')
  static Future<void> _startSearchingDevices(SendPort sendPort) async {
    final port = ReceivePort();
    sendPort.send(port.sendPort);

    await for (final message in port) {
      if (message is List<String>) {
        final String subnetIsolate = message[0];
        final int firstSubnetIsolate = int.parse(message[1]);
        final int lastSubnetIsolate = int.parse(message[2]);
        final int timeoutInSeconds = int.parse(message[3]);
        final bool resultsInAddressAscendingOrder = message[4] == "true";
        final String dbDirectory = message[5];
        final bool enableDebugging = message[6] == "true";
        final String joinedIds = message[7];
        final List<int> hostIds = joinedIds
            .split(',')
            .where((e) => e.isNotEmpty)
            .map(int.parse)
            .toList();
        // Configure again. The vendor table is skipped here: building it can
        // trigger a multi-second first-use download, and vendor lookups run in
        // the isolate that receives the hosts, not in this one.
        await configureNetworkTools(
          dbDirectory,
          enableDebugging: enableDebugging,
          buildVendorTable: false,
        );

        /// Will contain all the hosts that got discovered in the network, will
        /// be use inorder to cancel on dispose of the page.
        final Stream<SendableActiveHost> hostsDiscoveredInNetwork =
            HostScannerService.instance.getAllSendablePingableDevices(
              subnetIsolate,
              firstHostId: firstSubnetIsolate,
              lastHostId: lastSubnetIsolate,
              hostIds: hostIds,
              timeoutInSeconds: timeoutInSeconds,
              resultsInAddressAscendingOrder: resultsInAddressAscendingOrder,
            );

        await for (final SendableActiveHost activeHostFound
            in hostsDiscoveredInNetwork) {
          sendPort.send(activeHostFound);
        }
        sendPort.send('Done');
      }
    }
  }

  /// Scans for all hosts that have the specific port that was given.
  /// [resultsInAddressAscendingOrder] = false will return results faster but
  /// not in ascending order.
  /// [maxConcurrency] limits how many hosts are probed at the same time.
  @override
  Stream<ActiveHost> scanDevicesForSinglePort(
    String subnet,
    int port, {
    int firstHostId = HostScannerService.defaultFirstHostId,
    int lastHostId = HostScannerService.defaultLastHostId,
    Duration timeout = const Duration(milliseconds: 2000),
    ProgressCallback? progressCallback,
    bool resultsInAddressAscendingOrder = true,
    int maxConcurrency = PortScannerService.defaultMaxConcurrency,
  }) async* {
    final int lastValidSubnet = validateAndGetLastValidSubnet(
      subnet,
      firstHostId,
      lastHostId,
    );
    final List<int> hostIds = <int>[
      for (int i = firstHostId; i <= lastValidSubnet; i++) i,
    ];
    if (hostIds.isEmpty) {
      return;
    }

    // Bound the number of concurrent connections so a /24 scan does not open a
    // socket for every host at once.
    final Stream<ConcurrentResult<ActiveHost>> results =
        mapConcurrently<int, ActiveHost>(
          hostIds,
          (int id) => PortScannerService.instance.connectToPort(
            address: '$subnet.$id',
            port: port,
            timeout: timeout,
          ),
          maxConcurrency: maxConcurrency,
          onCompleted: (int completed) =>
              progressCallback?.call(completed * 100 / hostIds.length),
        );

    if (!resultsInAddressAscendingOrder) {
      await for (final ConcurrentResult<ActiveHost> result in results) {
        final ActiveHost? activeHost = result.value;
        if (activeHost != null) {
          yield activeHost;
        }
      }
      return;
    }

    // Keep the ascending-order contract even though connections finish out of
    // order by buffering results until every earlier host has been emitted.
    final Map<int, ActiveHost?> pending = <int, ActiveHost?>{};
    int nextIndex = 0;
    await for (final ConcurrentResult<ActiveHost> result in results) {
      pending[result.index] = result.value;
      while (pending.containsKey(nextIndex)) {
        final ActiveHost? activeHost = pending.remove(nextIndex);
        nextIndex++;
        if (activeHost != null) {
          yield activeHost;
        }
      }
    }
  }

  /// Defines total number of subnets in class A network
  final classASubnets = 16777216;

  /// Defines total number of subnets in class B network
  final classBSubnets = 65536;

  /// Defines total number of subnets in class C network
  final classCSubnets = 256;

  /// Minimum value of first octet in IPv4 address used by getMaxHost
  final int minNetworkId = 1;

  /// Maximum value of first octect in IPv4 address used by getMaxHost
  final int maxNetworkId = 223;

  /// returns the max number of hosts a subnet can have excluding network Id and broadcast Id
  @Deprecated(
    "Implementation is wrong, since we only append in last octet, max host can only be 254. Use maxHost getter",
  )
  int getMaxHost(String subnet) {
    if (subnet.isEmpty) {
      throw ArgumentError('Invalid subnet address, address can not be empty.');
    }
    final List<String> firstOctetStr = subnet.split('.');
    if (firstOctetStr.isEmpty) {
      throw ArgumentError(
        'Invalid subnet address, address should be in IPv4 format x.x.x',
      );
    }

    final int firstOctet = int.parse(firstOctetStr[0]);

    if (firstOctet >= minNetworkId && firstOctet < 128) {
      return classASubnets;
    } else if (firstOctet >= 128 && firstOctet < 192) {
      return classBSubnets;
    } else if (firstOctet >= 192 && firstOctet <= maxNetworkId) {
      return classCSubnets;
    }
    // Out of range for first octet
    throw RangeError.range(
      firstOctet,
      minNetworkId,
      maxNetworkId,
      'subnet',
      'Out of range for first octet',
    );
  }

  int get maxHost => HostScannerService.defaultLastHostId;
}
