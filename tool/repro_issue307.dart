// Reproduction for issue #307: iOS/Darwin host discovery disagrees with the
// router's client list, while Android is accurate.
//
// Usage:
//   dart run tool/repro_issue307.dart [subnet]
//
// `subnet` is optional (e.g. 192.168.1). Without it the prefix is taken from
// the interface the default route uses.
//
// It measures four things over the same address range:
//   A  ground truth: a host that answers TCP at all (accept OR refuse) is alive
//   C1 the shipped 14-port probe logic, "refused means up" set = {111, 10061}
//   C2 the same probe with Darwin's ECONNREFUSED (61) added to that set
//   B  the shipped scanner, restricted to the hosts A proved alive
// C1 vs C2 isolates the errno predicate; B vs A is what a user sees.
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/concurrency.dart';

/// The 14 ports the scanner probes, copied so the predicate can be swapped.
const List<int> _probePorts = [
  21,
  22,
  23,
  53,
  80,
  161,
  443,
  445,
  631,
  3389,
  5900,
  8080,
  8443,
  9100,
];

const Duration _timeout = Duration(seconds: 2);

/// Port used for the one-shot ground-truth probe. Deliberately outside the
/// probe set so a host is judged only by whether it answers at all.
const int _truthPort = 44555;

Future<void> main(List<String> arguments) async {
  final Directory dbDir = await Directory.systemTemp.createTemp('nt307_');
  await configureNetworkTools(dbDir.path, buildVendorTable: false);

  final String subnet = arguments.isNotEmpty
      ? arguments.first
      : await _detectSubnet();
  final List<int> ids = List<int>.generate(254, (int i) => i + 1);
  if (!RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(subnet)) {
    throw StateError('"$subnet" is not an IPv4 prefix like 192.168.1');
  }

  await _say('=== issue #307 reproduction ===');
  await _say(
    'platform : ${Platform.operatingSystem} '
    '${Platform.operatingSystemVersion}',
  );
  await _say('subnet   : $subnet.1 - $subnet.254');
  await _say('');

  final Map<String, String> probe = await _classifyRefusalError('$subnet.1');
  final int? probeCode = int.tryParse(probe['code'] ?? '');
  await _say('errno for a refused connect to ${probe['host']}:');
  await _say('  code=${probe['code']} message="${probe['message']}"');
  await _say(
    '  `_tryConnect` accepts up = {111, 10061} -> contains $probeCode: '
    '${const <int>[111, 10061].contains(probeCode)}',
  );
  await _say('');

  // A — ground truth. One port; accept or refuse both prove the host answered.
  await _say('A  ground-truth probe over ${ids.length} addresses ...');
  final Set<int> alive = <int>{};
  final Map<int, String> why = <int, String>{};
  final Stopwatch watchA = Stopwatch()..start();
  await mapConcurrently<int, int?>(ids, (int id) async {
    final String verdict = await _rawVerdict('$subnet.$id');
    if (verdict == 'open' || verdict.startsWith('refused')) {
      alive.add(id);
      why[id] = verdict;
      return id;
    }
    return null;
  }, maxConcurrency: 32).drain<void>();
  watchA.stop();
  final Map<String, int> verdictCounts = <String, int>{};
  for (final int id in ids) {
    final String v = why[id] ?? 'silent';
    verdictCounts[v] = (verdictCounts[v] ?? 0) + 1;
  }
  await _say('A  alive (accept OR refuse): ${alive.length} hosts');
  await _say('   ${watchA.elapsedMilliseconds} ms');
  await _say('   verdicts: $verdictCounts');
  await _say('');

  // C — the scanner's own 14-port probe, with the errno set injected.
  await _say('C  14-port TCP probe, refusal set varied ...');
  final Set<int> shipped = await _sweep(subnet, ids, const <int>{111, 10061});
  final Set<int> withDarwin = await _sweep(subnet, ids, const <int>{
    111,
    10061,
    61,
  });
  await _say('C1 refusal set {111,10061} (as shipped) : ${shipped.length}');
  await _say('C2 refusal set {111,10061,61} (+Darwin) : ${withDarwin.length}');
  await _say(
    '   the errno predicate alone hides '
    '${withDarwin.length - shipped.length} hosts',
  );
  await _say('');

  // B — the real scanner, limited to the hosts A proved alive so the ICMP
  // fallback does not spend a minute on the ~240 addresses that are empty.
  final List<int> subset = alive.toList()..sort();
  await _say(
    'B  shipped scanner over the ${subset.length} proven-live ids ...',
  );
  final List<String> reported = <String>[];
  bool stalled = false;
  final Stopwatch watchB = Stopwatch()..start();
  // Stream.timeout fires per gap between events, so this trips when the scan
  // goes quiet rather than when it runs long overall.
  await HostScannerService.instance
      .getAllSendablePingableDevices(subnet, hostIds: subset)
      .timeout(
        const Duration(seconds: 90),
        onTimeout: (EventSink<SendableActiveHost> sink) {
          stalled = true;
          sink.close();
        },
      )
      .forEach((SendableActiveHost host) => reported.add(host.address));
  watchB.stop();
  await _say('B  reported: ${reported.length} hosts in ${watchB.elapsed}');
  if (stalled) {
    await _say('   !! scan went silent for 90 s before finishing');
  }
  await _say('');

  final Set<String> reportedSet = reported.toSet();
  final List<int> missed = subset
      .where((int id) => !reportedSet.contains('$subnet.$id'))
      .toList();
  await _say('Proven alive by A but NOT reported by B: ${missed.length}');
  for (final int id in missed.take(25)) {
    await _say(
      '  $subnet.$id  raw=${why[id]}  '
      'tcp-as-shipped=${shipped.contains(id)}  '
      'tcp-with-61=${withDarwin.contains(id)}',
    );
  }
  if (missed.length > 25) {
    await _say('  ... and ${missed.length - 25} more');
  }

  await stdout.flush();
  try {
    await dbDir.delete(recursive: true);
  } on FileSystemException {
    // Temp database still locked; the report is already printed.
  }
}

Future<void> _say(String line) async {
  print(line);
  await stdout.flush();
}

/// What errno a refused connect produces on this OS, from the gateway.
Future<Map<String, String>> _classifyRefusalError(String host) async {
  for (final int port in <int>[_truthPort, _truthPort + 1, _truthPort + 2]) {
    try {
      final Socket s = await Socket.connect(host, port, timeout: _timeout);
      await s.close();
    } on SocketException catch (e) {
      return <String, String>{
        'host': host,
        'code': '${e.osError?.errorCode}',
        'message': e.osError?.message ?? e.message,
      };
    } on TimeoutException {
      continue;
    }
  }
  return <String, String>{
    'host': host,
    'code': '<none>',
    'message': 'no refusal observed on the probe ports',
  };
}

/// Single-port verdict for one address. Only a real refusal or an accept counts
/// as proof of life; DNS and routing failures are reported separately so they
/// cannot inflate the ground-truth set.
Future<String> _rawVerdict(String host) async {
  try {
    final Socket s = await Socket.connect(host, _truthPort, timeout: _timeout);
    await s.close();
    return 'open';
  } on SocketException catch (e) {
    final int? code = e.osError?.errorCode;
    final String msg = e.osError?.message ?? e.message;
    if (msg.toLowerCase().contains('refused') ||
        const <int>[61, 111, 10061].contains(code)) {
      return 'refused(code $code)';
    }
    return 'no-answer(code $code: $msg)';
  } on TimeoutException {
    return 'silent';
  } catch (e) {
    return 'error(${e.runtimeType})';
  }
}

/// Replica of `_probeHostViaTCP`, with the "refused means up" set injected.
Future<Set<int>> _sweep(String subnet, List<int> ids, Set<int> refusalCodes) {
  final Set<int> found = <int>{};
  return mapConcurrently<int, int?>(ids, (int id) async {
    final List<bool> answers = await Future.wait(
      _probePorts.map(
        (int port) => _tryConnect('$subnet.$id', port, refusalCodes),
      ),
    );
    if (answers.contains(true)) {
      found.add(id);
      return id;
    }
    return null;
  }, maxConcurrency: 32).drain<void>().then((_) => found);
}

Future<bool> _tryConnect(String host, int port, Set<int> refusalCodes) async {
  try {
    final Socket socket = await Socket.connect(host, port).timeout(_timeout);
    await socket.close();
    return true;
  } on SocketException catch (e) {
    return refusalCodes.contains(e.osError?.errorCode);
  } on TimeoutException {
    return false;
  } catch (e) {
    return false;
  }
}

Future<String> _detectSubnet() async {
  final List<NetworkInterface> interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
  );
  for (final NetworkInterface interface in interfaces) {
    if (interface.name.startsWith('en')) {
      final String address = interface.addresses.first.address;
      return address.substring(0, address.lastIndexOf('.'));
    }
  }
  throw StateError('No IPv4 subnet found; pass it as an argument.');
}
