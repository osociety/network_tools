// Live host-scan report for validating discovery speed and device names.
//
// Usage:
//   dart run tool/scan_report.dart [subnet]
//
// `subnet` is optional (e.g. 192.168.1). Without it the subnet is taken from
// the interface the default route uses.
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/device_info/arp_table_helper.dart';

Future<void> main(List<String> arguments) async {
  final Directory dbDir = await Directory.systemTemp.createTemp('nt_report_');
  await configureNetworkTools(dbDir.path);

  final String subnet = arguments.isNotEmpty
      ? arguments.first
      : await _detectSubnet();
  final String localAddress = '$subnet.x';

  print('=== network_tools scan report ===');
  print('platform      : ${Platform.operatingSystem}');
  print('subnet        : $subnet ($localAddress)');

  final Stopwatch tableWatch = Stopwatch()..start();
  final List<ARPData> table = await ARPTableHelper().buildNumericTable();
  tableWatch.stop();
  print('');
  print(
    'numeric ARP table: ${table.length} entries in '
    '${tableWatch.elapsedMilliseconds} ms',
  );
  for (final ARPData entry in table) {
    print(
      '  ${entry.iPAddress.padRight(15)} ${entry.macAddress} '
      'name="${entry.hostname}"',
    );
  }
  await stdout.flush();

  await _printPtrProbe(table);
  await _printScan(
    'getAllPingableDevices',
    (ProgressCallback onProgress) => HostScannerService.instance
        .getAllPingableDevices(subnet, progressCallback: onProgress),
  );
  await _printScan(
    'getAllPingableDevicesAsync',
    (ProgressCallback onProgress) => HostScannerService.instance
        .getAllPingableDevicesAsync(subnet, progressCallback: onProgress),
  );

  // Runs last because `arp -a` resolves every entry serially and can take
  // several seconds.
  final Stopwatch arpWatch = Stopwatch()..start();
  final ProcessResult arpResult = Process.runSync('arp', const ['-a']);
  arpWatch.stop();
  print('');
  print(
    'OS "arp -a" (reference): exit ${arpResult.exitCode} in '
    '${arpWatch.elapsedMilliseconds} ms',
  );
  for (final String line
      in const LineSplitter().convert(arpResult.stdout.toString()).take(15)) {
    print('  $line');
  }
  await stdout.flush();

  try {
    await dbDir.delete(recursive: true);
  } on FileSystemException {
    // The report is already printed; a locked temp database is harmless.
  }
}

/// Reverse lookups for the table entries, independent of the scanner.
Future<void> _printPtrProbe(List<ARPData> table) async {
  print('');
  print('PTR probe (Dart InternetAddress.reverse, 3s budget):');
  for (final ARPData entry in table) {
    final Stopwatch watch = Stopwatch()..start();
    String name;
    try {
      final InternetAddress resolved = await InternetAddress(
        entry.iPAddress,
      ).reverse().timeout(const Duration(seconds: 3));
      name = resolved.host;
    } on TimeoutException {
      name = '<timeout>';
    } on SocketException catch (error) {
      name = '<${error.osError?.message ?? error.message}>';
    } catch (error) {
      name = '<$error>';
    }
    print(
      '  ${entry.iPAddress.padRight(15)} -> $name '
      '(${watch.elapsedMilliseconds} ms)',
    );
  }
  await stdout.flush();
}

Future<String> _detectSubnet() async {
  try {
    final String? interfaceName = _defaultInterfaceName();
    if (interfaceName != null) {
      final List<NetworkInterface> interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: true,
      );
      for (final NetworkInterface interface in interfaces) {
        if (interface.name == interfaceName && interface.addresses.isNotEmpty) {
          final String address = interface.addresses.first.address;
          return address.substring(0, address.lastIndexOf('.'));
        }
      }
    }
  } catch (_) {
    // Fall through to the first available interface below.
  }
  final NetInterface? local = await NetInterface.localInterface();
  if (local == null) {
    throw StateError(
      'No IPv4 interface found; pass the subnet as an argument.',
    );
  }
  return local.networkId;
}

String? _defaultInterfaceName() {
  try {
    if (Platform.isMacOS) {
      final ProcessResult result = Process.runSync('route', const [
        '-n',
        'get',
        'default',
      ]);
      for (final String line in const LineSplitter().convert(
        result.stdout.toString(),
      )) {
        final String trimmed = line.trim();
        if (trimmed.startsWith('interface:')) {
          return trimmed.substring('interface:'.length).trim();
        }
      }
    } else if (Platform.isLinux) {
      final ProcessResult result = Process.runSync('ip', const [
        'route',
        'show',
        'default',
      ]);
      return RegExp(
        r'\bdev\s+(\S+)',
      ).firstMatch(result.stdout.toString())?.group(1);
    }
  } catch (_) {
    // Interface detection is best effort.
  }
  return null;
}

Future<void> _printScan(
  String label,
  Stream<ActiveHost> Function(ProgressCallback onProgress) scan,
) async {
  final Stopwatch watch = Stopwatch()..start();
  double? firstAt;
  final List<ActiveHost> hosts = <ActiveHost>[];
  final List<double> progress = <double>[];

  await for (final ActiveHost host in scan(progress.add)) {
    firstAt ??= watch.elapsedMilliseconds.toDouble();
    hosts.add(host);
  }
  watch.stop();

  print('');
  print(
    '$label: ${hosts.length} hosts, '
    'first result ${firstAt ?? '-'} ms, '
    'total ${watch.elapsedMilliseconds} ms, '
    'progress last ${progress.isEmpty ? '-' : progress.last}',
  );

  for (final ActiveHost host in hosts) {
    final Stopwatch detailWatch = Stopwatch()..start();
    final String? name = await host.hostName.timeout(
      const Duration(seconds: 3),
      onTimeout: () => null,
    );
    final String deviceName = await host.deviceName.timeout(
      const Duration(seconds: 3),
      onTimeout: () => '<timeout>',
    );
    detailWatch.stop();
    final String? mac = await host.getMacAddress();
    print(
      '  ${host.address.padRight(15)} mac=${mac ?? '-'} '
      'hostName=${name ?? '-'} deviceName=$deviceName '
      'ping=${host.responseTime?.inMilliseconds ?? '-'}ms '
      'details=${detailWatch.elapsedMilliseconds}ms',
    );
  }
  await stdout.flush();
}
