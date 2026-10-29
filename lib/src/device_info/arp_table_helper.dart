import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:network_tools/src/models/arp_data.dart';
import 'package:universal_io/io.dart';

/// Retreiving ARP packets is only supported for Desktop such as
/// Linux, Windows, and macOS. Dart native doesn't provide a way or rejects
/// call to arp command on mobile such as Android and iOS.
/// Maybe in future dart native will support sending raw packets,
/// so that time we can add implementation for mobile devices.
/// Currenlty this is achieved by process package.
/// Helper class for retrieving and parsing the ARP table on supported desktop platforms.
class ARPTableHelper {
  /// [runArp] and [linuxArpPath] exist so the platform fallbacks can be tested
  /// on any machine; production code uses the defaults.
  ARPTableHelper({
    ProcessResult Function(List<String> arguments)? runArp,
    String linuxArpPath = '/proc/net/arp',
  }) : _runArp = runArp ?? _defaultRunArp,
       _linuxArpPath = linuxArpPath;

  final ProcessResult Function(List<String> arguments) _runArp;
  final String _linuxArpPath;

  static ProcessResult _defaultRunArp(List<String> arguments) =>
      Process.runSync('arp', arguments);

  /// Logger for ARP table operations.
  static final arpLogger = Logger("arp-table-logger");

  bool isMobilePlatform = Platform.isAndroid || Platform.isIOS;
  bool isMacOSPlatform = Platform.isMacOS;
  bool isLinuxPlatform = Platform.isLinux;

  /// Whether the ARP table can be read on this platform.
  bool get isARPSupported => !isMobilePlatform;

  /// How long the kernel is given to resolve neighbors after priming.
  static const Duration defaultPrimingDelay = Duration(milliseconds: 150);

  List<String> executeARPCommand() {
    // ARP is not allowed to be run for mobile devices currenlty.
    if (isMobilePlatform) {
      arpLogger.warning("ARP command is not supported on mobile platforms.");
      return [];
    }
    try {
      final result = _runArp(['-a']);
      if (result.exitCode != 0) {
        arpLogger.warning("Failed to execute ARP command: ${result.stderr}");
        return [];
      }
      return const LineSplitter().convert(result.stdout.toString());
    } on ProcessException catch (error) {
      // The arp binary can be missing on minimal systems (containers, some
      // Linux images). Host discovery still works, only MAC data is missing.
      arpLogger.warning("ARP command is unavailable: $error");
      return [];
    } catch (error, stackTrace) {
      arpLogger.warning(
        "Unexpected error while running ARP command: $error",
        error,
        stackTrace,
      );
      return [];
    }
  }

  /// Reads the ARP table without asking the OS to resolve host names.
  ///
  /// `arp -a` performs a reverse DNS lookup for every entry, which can block
  /// for seconds and frequently yields `?` anyway. Discovery only needs the
  /// address and MAC, so read the numeric form and resolve names separately
  /// for the hosts that were actually found.
  List<String> executeNumericARPCommand() {
    if (isMobilePlatform) {
      arpLogger.warning("ARP table is not available on mobile platforms.");
      return [];
    }
    if (isLinuxPlatform) {
      final procEntries = _readLinuxProcNetArp();
      if (procEntries != null) {
        return procEntries;
      }
    }
    try {
      // Keep the Linux fallback numeric too: `arp -a` performs a reverse
      // lookup per row, which is what this method exists to avoid. Windows
      // has no `-n` flag and prints numeric rows anyway.
      final arguments = (isMacOSPlatform || isLinuxPlatform)
          ? const <String>['-an']
          : const <String>['-a'];
      final result = _runArp(arguments);
      if (result.exitCode != 0) {
        arpLogger.warning("Failed to execute ARP command: ${result.stderr}");
        return [];
      }
      return const LineSplitter().convert(result.stdout.toString());
    } on ProcessException catch (error) {
      // The arp binary can be missing on minimal systems (containers, some
      // Linux images). Host discovery still works, only MAC data is missing.
      arpLogger.warning("ARP command is unavailable: $error");
      return [];
    } catch (error, stackTrace) {
      arpLogger.warning(
        "Unexpected error while running ARP command: $error",
        error,
        stackTrace,
      );
      return [];
    }
  }

  /// Linux exposes the neighbor table directly, avoiding both a process spawn
  /// and name resolution. Rows are converted to the `arp -a` line format so
  /// both code paths share the same parser.
  List<String>? _readLinuxProcNetArp() {
    try {
      final file = File(_linuxArpPath);
      if (!file.existsSync()) {
        return null;
      }
      final entries = <String>[];
      for (final line in file.readAsLinesSync().skip(1)) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 6) {
          continue;
        }
        final String ip = parts[0];
        final int? flags = int.tryParse(
          parts[2].replaceFirst('0x', ''),
          radix: 16,
        );
        // 0x2 is ATF_COM: the entry is complete and usable.
        if (flags == null || flags & 0x2 == 0) {
          continue;
        }
        entries.add('? ($ip) at ${parts[3]} [ether] on ${parts[5]}');
      }
      return entries;
    } catch (error, stackTrace) {
      arpLogger.fine("Unable to read /proc/net/arp: $error", error, stackTrace);
      return null;
    }
  }

  RegExp _getARPCmdRegExPattern() {
    if (isMacOSPlatform) {
      return RegExp(
        r'(?<host>[\w.?]*)\s\((?<ip>.*)\)\sat\s(?<mac>.*)\son\s(?<intf>\w+)\sifscope\s*(\w*)\s*\[(?<typ>.*)\]',
      );
    } else if (isLinuxPlatform) {
      return RegExp(
        r'(?<host>[\w.?]*)\s\((?<ip>.*)\)\sat\s(?<mac>.*)\s\[(?<typ>.*)\]\son\s(?<intf>\w+)',
      );
    } else {
      // Windows: non-greedy match and trim whitespace
      return RegExp(
        r'(?<ip>[^\s]+)\s+(?<mac>[^\s]+)\s+(?<typ>\w+)',
        caseSensitive: false,
      );
    }
  }

  /// Retrieves the ARP table by running the `arp -a` command on Linux, Windows, and macOS.
  ///
  /// Parses the output and returns a list of [ARPData] objects representing each ARP entry.
  /// Returns an empty list on unsupported platforms (e.g., Android, iOS).
  Future<List<ARPData>> buildTable() async {
    return _parseEntries(executeARPCommand());
  }

  /// Retrieves the ARP table without asking the OS to resolve host names.
  ///
  /// Host names are resolved separately for the hosts that were actually found,
  /// which is both faster and more reliable than the serial lookups performed
  /// by `arp -a`.
  Future<List<ARPData>> buildNumericTable() async {
    final int startTime = DateTime.now().millisecondsSinceEpoch;
    final entries = _parseEntries(executeNumericARPCommand());
    arpLogger.fine(
      "Numeric ARP read took ${DateTime.now().millisecondsSinceEpoch - startTime} ms with ${entries.length} entries",
    );
    return entries;
  }

  /// Asks the kernel to resolve link-layer addresses for [hosts] by sending a
  /// throwaway UDP datagram to each of them, then waits [settleDelay] so the
  /// neighbor table is populated before it is read.
  ///
  /// The datagrams never need an answer; they only trigger ARP resolution.
  Future<void> primeARPCache(
    Iterable<String> hosts, {
    Duration settleDelay = defaultPrimingDelay,
    int port = 9,
  }) async {
    if (!isARPSupported || hosts.isEmpty) {
      return;
    }
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      const List<int> payload = <int>[0];
      for (final host in hosts) {
        final address = InternetAddress.tryParse(host);
        if (address == null) {
          continue;
        }
        socket.send(payload, address, port);
      }
      // Give the kernel a moment to flush the datagrams before closing.
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } catch (error, stackTrace) {
      arpLogger.fine(
        "Unable to prime the ARP cache: $error",
        error,
        stackTrace,
      );
    } finally {
      socket?.close();
    }
    await Future<void>.delayed(settleDelay);
  }

  List<ARPData> _parseEntries(List<String> entries) {
    final Map<String, ARPData> arpEntries = {};
    final int startTime = DateTime.now().millisecondsSinceEpoch;
    if (entries.isEmpty) {
      arpLogger.warning("No ARP entries found.");
      return [];
    }

    final pattern = _getARPCmdRegExPattern();

    for (final entry in entries) {
      // Skip Windows header and interface lines
      if (entry.trim().isEmpty ||
          entry.startsWith('Interface:') ||
          entry.trim().toLowerCase().startsWith('internet address')) {
        continue;
      }
      final match = pattern.firstMatch(entry);
      if (match == null) {
        continue;
      }
      try {
        final arpData = ARPData.fromRegExpMatch(match);
        // Localized headers can accidentally match the Windows pattern. Only
        // accept entries that actually contain a MAC address.
        final String? macAddress = _normalizeMacAddress(arpData.macAddress);
        if (macAddress == null || !_isUnicastMacAddress(macAddress)) {
          arpLogger.fine(
            "Skipping ARP entry with unusable MAC address: $entry",
          );
          continue;
        }
        // macOS prints octets without leading zeroes (e.g. d6:68:8b:9:0:7),
        // so pad them to keep MAC and vendor lookups consistent across
        // platforms.
        final ARPData normalized = ARPData(
          hostname: arpData.hostname,
          iPAddress: arpData.iPAddress,
          macAddress: macAddress,
          interfaceName: arpData.interfaceName,
          interfaceType: arpData.interfaceType,
          createdAt: arpData.createdAt,
        );
        arpLogger.fine("Adding entry to table -> $normalized");
        arpEntries[normalized.iPAddress] = normalized;
      } catch (error) {
        arpLogger.fine("Skipping unparsable ARP entry: $entry ($error)");
      }
    }
    arpLogger.fine(
      "ARP calculation took ${DateTime.now().millisecondsSinceEpoch - startTime} ms with ${arpEntries.length} entries",
    );
    return arpEntries.values.toList();
  }

  /// Accepts MAC addresses with or without leading zeroes per octet and
  /// returns a padded form, preserving the original separator. Returns null for
  /// `(incomplete)` entries and anything that is not a MAC address.
  static String? _normalizeMacAddress(String macAddress) {
    final List<String> parts = macAddress.split(RegExp('[:-]'));
    if (parts.length != 6) {
      return null;
    }
    final String separator = macAddress.contains('-') ? '-' : ':';
    final List<String> normalized = <String>[];
    for (final String part in parts) {
      if (!RegExp(r'^[0-9a-fA-F]{1,2}$').hasMatch(part)) {
        return null;
      }
      normalized.add(part.padLeft(2, '0'));
    }
    return normalized.join(separator);
  }

  /// Whether [macAddress] belongs to a single interface.
  ///
  /// Broadcast and multicast addresses are not devices: priming the cache
  /// creates a broadcast row for the subnet broadcast address, and Windows
  /// keeps multicast rows around.
  static bool _isUnicastMacAddress(String macAddress) {
    final List<int> octets = macAddress
        .split(RegExp('[:-]'))
        .map((part) => int.parse(part, radix: 16))
        .toList();
    // Bit 0 of the first octet is the group bit.
    if (octets[0].isOdd) {
      return false;
    }
    return octets.any((octet) => octet != 0);
  }
}
