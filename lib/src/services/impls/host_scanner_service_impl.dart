import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:dart_ping/dart_ping.dart';
import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/concurrency.dart';
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
    Future<Isolate> Function(
      void Function(SendPort) entryPoint,
      SendPort sendPort,
      SendPort errorPort,
      SendPort exitPort,
    )?
    spawnScanIsolate,
  }) : _spawnScanIsolate = spawnScanIsolate ?? _spawnHostScanIsolate;

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

  /// Upper bound for concurrent per-host verification and name lookups.
  /// Mobile platforms get lower concurrency to avoid overwhelming their network stacks.
  static int get hostLookupConcurrency {
    if (Platform.isAndroid || Platform.isIOS) {
      return 32;
    }
    return 128;
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
    int timeoutInSeconds = 2,
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
    int timeoutInSeconds = 2,
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
    // Report 0% immediately so the UI shows progress has started
    progressCallback?.call(0);
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
                // TCP phase covers 0-95% since it finds almost all devices
                final tcpProgress = (completedProbes / totalProbes) * 95;
                progressCallback(tcpProgress);
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
                  // No ping fallback needed, jump to 100%
                  if (progressCallback != null) {
                    progressCallback(100);
                  }
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
                      // Ping fallback covers 95-100%
                      final pingProgress =
                          95 + (completedPings / totalPings) * 5;
                      progressCallback(pingProgress);
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
                      // Ping fallback covers 95-100%
                      final pingProgress =
                          95 + (completedPings / totalPings) * 5;
                      progressCallback(pingProgress);
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

    // Ensure progress reaches 100% at the end
    progressCallback?.call(100);

    final elapsed = stopwatch.elapsedMilliseconds;
    logger.info(
      'TCP-connect sweep completed (ordered): $hostsFound hosts found in ${elapsed}ms',
    );
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
    // Includes web, shell, network service, printer, and Windows ports.
    const ports = [
      21, // FTP (NAS, routers)
      22, // SSH
      23, // Telnet
      53, // DNS
      80, // HTTP
      161, // SNMP
      443, // HTTPS
      445, // SMB (Windows file sharing)
      631, // IPP (printers)
      3389, // RDP (Windows remote desktop)
      5900, // VNC
      8080, // HTTP-alt
      8443, // HTTPS-alt
      9100, // JetDirect (network printers)
    ];
    final futures = ports.map((port) => _tryConnect(host, port, timeout));
    final results = await Future.wait(futures);

    // Collect all open ports
    final openPorts = <OpenPort>[];
    for (int i = 0; i < ports.length; i++) {
      if (results[i]) {
        openPorts.add(OpenPort(ports[i]));
      }
    }

    // If any port responded (success or connection-refused), host is up.
    final isUp = openPorts.isNotEmpty;

    if (isUp) {
      final respondedPort = openPorts.first.port;
      logger.fine('[TCP Probe] $host is UP (port $respondedPort responded)');
      final result = SendableActiveHost(
        host,
        openPorts: openPorts,
        deviceType: _inferDeviceType(openPorts),
      );
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

  /// Infers device type based on open port patterns.
  ///
  /// Uses common port combinations to identify device types like routers,
  /// printers, Windows PCs, etc.
  String _inferDeviceType(List<OpenPort> openPorts) {
    final portNumbers = openPorts.map((p) => p.port).toSet();

    // Printer: IPP (631) or JetDirect (9100) - most specific
    if (portNumbers.contains(631) || portNumbers.contains(9100)) {
      return 'Printer';
    }

    // NAS: FTP (21) + SMB (445) - check before Windows PC
    if (portNumbers.contains(21) && portNumbers.contains(445)) {
      return 'NAS';
    }

    // Router/Gateway: DNS (53) + typically SNMP (161) or multiple web ports
    if (portNumbers.contains(53) &&
        (portNumbers.contains(161) ||
            portNumbers.contains(80) ||
            portNumbers.contains(443) ||
            portNumbers.contains(8080) ||
            portNumbers.contains(8443))) {
      return 'Router';
    }

    // Generic server: SSH (22) + both HTTP and HTTPS (3+ ports total)
    if (portNumbers.contains(22) &&
        portNumbers.contains(80) &&
        portNumbers.contains(443)) {
      return 'Server';
    }

    // Linux/Unix server: SSH (22) + web services (HTTP or HTTPS, not both)
    if (portNumbers.contains(22) &&
        (portNumbers.contains(80) ||
            portNumbers.contains(443) ||
            portNumbers.contains(8080))) {
      return 'Linux Server';
    }

    // Windows PC: SMB (445) and/or RDP (3389) - after NAS check
    if (portNumbers.contains(445) || portNumbers.contains(3389)) {
      return 'Windows PC';
    }

    // Device with only SSH
    if (portNumbers.contains(22) && portNumbers.length == 1) {
      return 'Linux/Unix Device';
    }

    // Web Device: HTTP + HTTPS specifically (2 ports)
    if (portNumbers.contains(80) &&
        portNumbers.contains(443) &&
        portNumbers.length == 2) {
      return 'Web Device';
    }

    // IoT device: limited ports (1-2), often just HTTP or HTTP-alt
    if (portNumbers.length <= 2 &&
        (portNumbers.contains(80) ||
            portNumbers.contains(443) ||
            portNumbers.contains(8080))) {
      return 'IoT Device';
    }

    // VNC-only device (remote display/management)
    if (portNumbers.contains(5900) && portNumbers.length == 1) {
      return 'Remote Display';
    }

    return 'Unknown Device';
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

  Future<SendableActiveHost?> getHostFromPing({
    required String host,
    required StreamController<SendableActiveHost>? activeHostsController,
    int timeoutInSeconds = 2,
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
    int timeoutInSeconds = 2,
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

  /// Test-only accessor for device type inference logic.
  String testInferDeviceType(List<OpenPort> openPorts) =>
      _inferDeviceType(openPorts);
}
