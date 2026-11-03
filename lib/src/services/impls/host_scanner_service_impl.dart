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

/// Spawns the host scan isolate with its error and exit ports wired up.
Future<Isolate> _spawnHostScanIsolate(
  void Function(SendPort) entryPoint,
  SendPort sendPort,
  SendPort errorPort,
  SendPort exitPort,
) => Isolate.spawn(entryPoint, sendPort, onError: errorPort, onExit: exitPort);

/// Scans for all hosts in a subnet.
class HostScannerServiceImpl extends HostScannerService {
  HostScannerServiceImpl({
    ARPTableHelper? arpTableHelper,
    Future<bool> Function(String subnet)? isLocalSubnet,
    Future<Isolate> Function(
      void Function(SendPort) entryPoint,
      SendPort sendPort,
      SendPort errorPort,
      SendPort exitPort,
    )?
    spawnScanIsolate,
  }) : _arpTableHelper = arpTableHelper ?? ARPTableHelper(),
       _isLocalSubnet = isLocalSubnet ?? _defaultIsLocalSubnet,
       _spawnScanIsolate = spawnScanIsolate ?? _spawnHostScanIsolate;

  final ARPTableHelper _arpTableHelper;
  final Future<bool> Function(String subnet) _isLocalSubnet;

  /// Spawns the isolate behind [getAllPingableDevicesAsync].
  ///
  /// Replaceable so tests can simulate an isolate that crashes or exits before
  /// the scan finishes.
  final Future<Isolate> Function(
    void Function(SendPort) entryPoint,
    SendPort sendPort,
    SendPort errorPort,
    SendPort exitPort,
  )
  _spawnScanIsolate;

  /// Budget for the host name lookup that runs during discovery.
  ///
  /// Short on purpose: networks without working reverse DNS make every lookup
  /// wait for the full budget before a host is emitted. [ActiveHost.hostName]
  /// retries lazily with a longer timeout, so a slow lookup here never removes
  /// the name from the result.
  static const Duration preferredHostNameTimeout = Duration(milliseconds: 250);

  /// Upper bound for concurrent per-host verification and name lookups.
  /// Mobile platforms get lower concurrency to avoid overwhelming their network stacks.
  static int get hostLookupConcurrency {
    if (Platform.isAndroid || Platform.isIOS) {
      return 32;
    }
    return 128;
  }

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
    // Start the mDNS scan in parallel with the host scan. The results are
    // merged by IP address so that devices like Android phones that don't
    // register reverse DNS records can still get their names from mDNS
    // advertisements.
    final Future<Map<String, MdnsInfo>> mdnsMapFuture = _buildMdnsMap();

    final stream = getAllSendablePingableDevices(
      subnet,
      firstHostId: firstHostId,
      lastHostId: lastHostId,
      hostIds: hostIds,
      timeoutInSeconds: timeoutInSeconds,
      progressCallback: progressCallback,
      resultsInAddressAscendingOrder: resultsInAddressAscendingOrder,
    );

    // Wait for the mDNS scan to complete before yielding hosts, so that every
    // host can be enriched with mDNS info if available.
    final Map<String, MdnsInfo> mdnsMap = await mdnsMapFuture;

    await for (final sendableActiveHost in stream) {
      // Host details (host name, ARP, vendor) resolve lazily, so they do not
      // delay discovery. Awaiting each host's resolveInfo() here used to
      // serialize a reverse DNS lookup per device.
      final host = ActiveHost.fromSendableActiveHost(
        sendableActiveHost: sendableActiveHost,
      );
      // Attach mDNS info if we found this host in the mDNS scan.
      final mdnsInfo = mdnsMap[host.address];
      if (mdnsInfo != null) {
        host.attachMdnsInfo(mdnsInfo);
      }
      yield host;
    }
  }

  /// Runs an mDNS scan and returns a map of IP address to [MdnsInfo].
  ///
  /// This is used to enrich hosts found by the regular scan with mDNS
  /// advertisements, so that devices like Android phones can get their names
  /// even when reverse DNS fails.
  Future<Map<String, MdnsInfo>> _buildMdnsMap() async {
    try {
      final mdnsHosts = await MdnsScannerService.instance.searchMdnsDevices();
      final map = <String, MdnsInfo>{};
      for (final host in mdnsHosts) {
        final mdnsInfo = await host.mdnsInfo;
        if (mdnsInfo != null) {
          map[host.address] = mdnsInfo;
        }
      }
      return map;
    } catch (e, stackTrace) {
      logger.warning(
        'mDNS scan failed during host discovery: $e',
        e,
        stackTrace,
      );
      return {};
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

    // Use TCP-connect sweep on all platforms for consistent results.
    // The ARP fast path was unreliable on some platforms (macOS) and caused
    // inconsistent device counts between mobile and desktop.
    // ARP is still used to enrich results with MAC addresses when available.
    yield* _yieldTCPConnectResults(
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
    final stopwatch = Stopwatch()..start();
    logger.info('ARP sweep: starting scan of ${idsToScan.length} hosts');

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

    int hostsFound = 0;
    final Stream<ConcurrentResult<SendableActiveHost?>>
    results = mapConcurrently<int, SendableActiveHost?>(candidates, (int id) {
      final String host = '$subnet.$id';
      final ARPData? arpData = byAddress[host];
      if (arpData != null) {
        return _verifyARPHost(host, arpData, timeoutInSeconds).then((host) {
          hostsFound++;
          final elapsed = stopwatch.elapsedMilliseconds;
          logger.info('ARP: found $host at ${elapsed}ms (total: $hostsFound)');
          return host;
        });
      }
      return getHostFromPing(
        activeHostsController: null,
        host: host,
        timeoutInSeconds: timeoutInSeconds,
      ).then((host) {
        if (host != null) {
          hostsFound++;
          final elapsed = stopwatch.elapsedMilliseconds;
          logger.info(
            'ARP (ping fallback): found $host at ${elapsed}ms (total: $hostsFound)',
          );
        }
        return host;
      });
    }, maxConcurrency: hostLookupConcurrency);

    if (!resultsInAddressAscendingOrder) {
      await for (final ConcurrentResult<SendableActiveHost?> result
          in results) {
        final SendableActiveHost? host = result.value;
        if (host != null) {
          yield host;
        }
      }
      final elapsed = stopwatch.elapsedMilliseconds;
      logger.info(
        'ARP sweep completed (unordered): $hostsFound hosts found in ${elapsed}ms',
      );
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
    final elapsed = stopwatch.elapsedMilliseconds;
    logger.info(
      'ARP sweep completed (ordered): $hostsFound hosts found in ${elapsed}ms',
    );
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

  /// TCP-connect sweep: no process spawns, works on all platforms.
  ///
  /// Tries to connect to common ports on each host. Connection-refused (errno 111
  /// on Linux/Android, 10061 on Windows) means the host is up but the port is
  /// closed; timeout or other errors mean the host is down.
  ///
  /// After TCP-connect completes, runs ICMP ping as a fallback for hosts that
  /// didn't respond to TCP. This ensures we find devices that block TCP but
  /// respond to ping (like some routers and IoT devices).
  Stream<SendableActiveHost> _yieldTCPConnectResults({
    required String subnet,
    required List<int> idsToScan,
    required int firstHostId,
    required int lastValidSubnet,
    required int timeoutInSeconds,
    required bool resultsInAddressAscendingOrder,
    ProgressCallback? progressCallback,
  }) async* {
    final stopwatch = Stopwatch()..start();
    final timeout = Duration(seconds: timeoutInSeconds);
    final StreamController<SendableActiveHost>? activeHostsController =
        resultsInAddressAscendingOrder
        ? null
        : StreamController<SendableActiveHost>();

    logger.info(
      'TCP-connect sweep: starting scan of ${idsToScan.length} hosts',
    );
    int hostsFound = 0;
    final Set<int> foundHostIds = {};

    // Use bounded concurrency for TCP probes to avoid overwhelming mobile devices
    final tcpResults = mapConcurrently<int, SendableActiveHost?>(idsToScan, (
      int id,
    ) async {
      final host = await _probeHostViaTCP(
        '$subnet.$id',
        timeout,
        activeHostsController,
      );
      if (host != null) {
        hostsFound++;
        foundHostIds.add(id);
        final elapsed = stopwatch.elapsedMilliseconds;
        logger.info(
          'TCP-connect: found $subnet.$id at ${elapsed}ms (total: $hostsFound)',
        );
      }
      return host;
    }, maxConcurrency: hostLookupConcurrency);

    if (!resultsInAddressAscendingOrder) {
      // Track progress for unordered mode
      int completedProbes = 0;
      final totalProbes = idsToScan.length;

      // Process TCP results as they complete and emit to stream
      unawaited(
        tcpResults
            .forEach((result) {
              completedProbes++;
              if (progressCallback != null && totalProbes > 0) {
                final tcpProgress = (completedProbes / totalProbes) * 50;
                progressCallback!(tcpProgress);
              }
            })
            .then(
              (_) async {
                // After TCP-connect completes, run ICMP ping fallback for missing
                // hosts with bounded concurrency so Android is not overwhelmed.
                final missingHostIds = idsToScan
                    .where((id) => !foundHostIds.contains(id))
                    .toList();
                if (missingHostIds.isEmpty) {
                  activeHostsController?.close();
                  return;
                }

                logger.info(
                  'Ping fallback: probing ${missingHostIds.length} hosts',
                );
                int completedPings = 0;
                final totalPings = missingHostIds.length;

                final pingResults = mapConcurrently<int, SendableActiveHost?>(
                  missingHostIds,
                  (int id) async {
                    final host = '$subnet.$id';
                    final pingResult = await getHostFromPing(
                      activeHostsController: activeHostsController,
                      host: host,
                      timeoutInSeconds: timeoutInSeconds,
                    );
                    if (pingResult != null) {
                      logger.info('Ping fallback: found $host');
                    }
                    completedPings++;
                    if (progressCallback != null && totalPings > 0) {
                      final pingProgress =
                          50 + (completedPings / totalPings) * 50;
                      progressCallback!(pingProgress);
                    }
                    return pingResult;
                  },
                  maxConcurrency: hostLookupConcurrency,
                );

                await for (final _ in pingResults) {
                  // drain the stream to completion
                }
                activeHostsController?.close();
                final elapsed = stopwatch.elapsedMilliseconds;
                logger.info(
                  'TCP-connect sweep completed: $hostsFound hosts found in ${elapsed}ms',
                );
              },
              onError: (Object _) async {
                final missingHostIds = idsToScan
                    .where((id) => !foundHostIds.contains(id))
                    .toList();
                if (missingHostIds.isEmpty) {
                  activeHostsController?.close();
                  return;
                }

                logger.info(
                  'Ping fallback: probing ${missingHostIds.length} hosts',
                );
                int completedPings = 0;
                final totalPings = missingHostIds.length;

                final pingResults = mapConcurrently<int, SendableActiveHost?>(
                  missingHostIds,
                  (int id) async {
                    final host = '$subnet.$id';
                    final pingResult = await getHostFromPing(
                      activeHostsController: activeHostsController,
                      host: host,
                      timeoutInSeconds: timeoutInSeconds,
                    );
                    if (pingResult != null) {
                      logger.info('Ping fallback: found $host');
                    }
                    completedPings++;
                    if (progressCallback != null && totalPings > 0) {
                      final pingProgress =
                          50 + (completedPings / totalPings) * 50;
                      progressCallback!(pingProgress);
                    }
                    return pingResult;
                  },
                  maxConcurrency: hostLookupConcurrency,
                );

                await for (final _ in pingResults) {
                  // drain the stream to completion
                }
                activeHostsController?.close();
                final elapsed = stopwatch.elapsedMilliseconds;
                logger.info(
                  'TCP-connect sweep completed: $hostsFound hosts found in ${elapsed}ms',
                );
              },
            ),
      );
      yield* activeHostsController!.stream;
      return;
    }

    // Ordered mode: collect all TCP results, then yield in order
    final tcpResultsMap = <int, SendableActiveHost?>{};
    int tcpIndex = 0;
    await for (final concurrentResult in tcpResults) {
      final id = idsToScan[tcpIndex];
      tcpResultsMap[id] = concurrentResult.value;
      progressCallback?.call(_progressFor(id, firstHostId, lastValidSubnet));
      tcpIndex++;
    }

    // Yield TCP results in order
    for (final id in idsToScan) {
      final tempHost = tcpResultsMap[id];
      if (tempHost != null) {
        yield tempHost;
      }
    }

    // After TCP-connect completes, run ICMP ping fallback for missing hosts
    // with bounded concurrency.
    final missingHostIds = idsToScan
        .where((id) => !foundHostIds.contains(id))
        .toList();
    if (missingHostIds.isNotEmpty) {
      logger.info('Ping fallback: probing ${missingHostIds.length} hosts');

      final pingFutures = <int, Future<SendableActiveHost?>>{};
      final pingResults = mapConcurrently<int, SendableActiveHost?>(
        missingHostIds,
        (int id) {
          final host = '$subnet.$id';
          final future = getHostFromPing(
            activeHostsController: null,
            host: host,
            timeoutInSeconds: timeoutInSeconds,
          );
          pingFutures[id] = future;
          return future;
        },
        maxConcurrency: hostLookupConcurrency,
      );

      // Drain the concurrent stream to let all pings run
      await for (final _ in pingResults) {
        // results are collected in pingFutures
      }

      // Yield results in order
      for (final id in missingHostIds) {
        final pingResult = await pingFutures[id];
        if (pingResult != null) {
          progressCallback?.call(
            _progressFor(id, firstHostId, lastValidSubnet),
          );
          logger.info('Ping fallback: found $subnet.$id');
          yield pingResult;
        }
      }
    }

    final elapsed = stopwatch.elapsedMilliseconds;
    logger.info(
      'TCP-connect sweep completed (ordered): $hostsFound hosts found in ${elapsed}ms',
    );
  }

  /// ICMP ping fallback for hosts that didn't respond to TCP-connect.
  ///
  /// This catches devices that block TCP but respond to ping (some routers,
  /// IoT devices, firewalls). Only runs for hosts not already found by TCP.
  Stream<SendableActiveHost> _yieldPingFallback({
    required String subnet,
    required List<int> idsToScan,
    required Set<int> foundHostIds,
    required int timeoutInSeconds,
  }) async* {
    final missingHostIds = idsToScan
        .where((id) => !foundHostIds.contains(id))
        .toList();
    if (missingHostIds.isEmpty) {
      logger.fine('Ping fallback: all hosts found via TCP, skipping');
      return;
    }

    logger.info(
      'Ping fallback: probing ${missingHostIds.length} hosts that missed TCP',
    );

    for (final id in missingHostIds) {
      final host = '$subnet.$id';
      final pingResult = await getHostFromPing(
        activeHostsController: null,
        host: host,
        timeoutInSeconds: timeoutInSeconds,
      );
      if (pingResult != null) {
        logger.info('Ping fallback: found $host');
        yield pingResult;
      }
    }
  }

  /// Probes a host via TCP-connect to common ports.
  ///
  /// Tries multiple common ports in parallel. Returns a
  /// [SendableActiveHost] if the host is up (any connection succeeded or
  /// connection-refused), or null if the host is down (all ports timed out).
  Future<SendableActiveHost?> _probeHostViaTCP(
    String host,
    Duration timeout,
    StreamController<SendableActiveHost>? activeHostsController,
  ) async {
    // Try multiple common ports in parallel. If ANY responds, the host is up.
    // Include common router/admin ports: 80, 443, 22, 23, 8080, 8443
    const ports = [80, 443, 22, 23, 8080, 8443, 53, 161];
    final futures = ports.map((port) => _tryConnect(host, port, timeout));
    final results = await Future.wait(futures);

    // If any port responded (success or connection-refused), host is up.
    final isUp = results.any((result) => result);

    if (isUp) {
      final respondedPort = ports[results.indexOf(true)];
      logger.fine('[TCP Probe] $host is UP (port $respondedPort responded)');
      final result = SendableActiveHost(host);
      if (activeHostsController != null && !activeHostsController.isClosed) {
        activeHostsController.add(result);
      }
      return result;
    }

    logger.fine(
      '[TCP Probe] $host is DOWN (all ${ports.length} ports timed out after ${timeout.inMilliseconds}ms)',
    );
    return null;
  }

  /// Tries to connect to a specific port. Returns true if the host responded
  /// (connection succeeded or connection-refused), false if timed out.
  Future<bool> _tryConnect(String host, int port, Duration timeout) async {
    try {
      final socket = await Socket.connect(host, port).timeout(timeout);
      await socket.close();
      return true; // Port open
    } on SocketException catch (e) {
      // errno 111 = ECONNREFUSED on Linux/Android; 10061 on Windows.
      // Both mean the host is up but the port is closed.
      final errorCode = e.osError?.errorCode;
      return errorCode == 111 || errorCode == 10061;
    } on TimeoutException {
      return false; // Host down or port filtered
    } catch (e) {
      return false;
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
    final errorPort = ReceivePort();
    final exitPort = ReceivePort();
    // An isolate that dies before sending 'Done' would otherwise leave this
    // stream waiting forever, so both failure channels feed the message stream.
    final errorSubscription = errorPort.listen((dynamic error) {
      receivePort.sendPort.send(<Object?>['runtimeError', error]);
    });
    final exitSubscription = exitPort.listen((dynamic _) {
      receivePort.sendPort.send(<Object?>['runtimeError', 'isolate exited']);
    });
    Isolate? isolate;

    try {
      isolate = await _spawnScanIsolate(
        _startSearchingDevices,
        receivePort.sendPort,
        errorPort.sendPort,
        exitPort.sendPort,
      );

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
        } else if (message is List && message.first == 'runtimeError') {
          throw Exception('Host scan isolate failed: ${message[1]}');
        } else if (message is String && message == 'Done') {
          // The isolate sends one message per host, so the scan can finish on
          // host ids below 254 without the last host reporting 100.
          progressCallback?.call(100);
          break;
        } else if (message is String && message.startsWith('Error:')) {
          throw Exception(
            'Host scan isolate failed: ${message.substring(6).trim()}',
          );
        }
      }
    } finally {
      // Also runs when the consumer cancels the stream early.
      await errorSubscription.cancel();
      await exitSubscription.cancel();
      errorPort.close();
      exitPort.close();
      isolate?.kill();
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
        try {
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
        } catch (error) {
          sendPort.send('Error: $error');
        }
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
