import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:network_tools/network_tools.dart';

void main() {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((record) {
    print(
      '${DateFormat.Hms().format(record.time)}: ${record.level.name}: ${record.loggerName}: ${record.message}',
    );
  });

  const String address = '192.168.1.1';
  // or You can also get address using network_info_plus package
  // final String? address = await (NetworkInfo().getWifiIP());
  final String subnet = address.substring(0, address.lastIndexOf('.'));

  // [New] Scan for a single open port in a subnet
  // You can set [firstHostId] and scan will start from this host in the network.
  // Similarly set [lastHostId] and scan will end at this host in the network.
  final stream2 = HostScanner.scanDevicesForSinglePort(
    subnet,
    53,
    // firstHostId: 1,
    // lastHostId: 254,
    progressCallback: (progress) {
      log.finer('Progress for port discovery on host : $progress');
    },
  );

  stream2.listen(
    (activeHost) {
      final OpenPort deviceWithOpenPort = activeHost.openPort[0];
      if (deviceWithOpenPort.isOpen) {
        log.fine(
          'Found open port: ${deviceWithOpenPort.port} on ${activeHost.address}',
        );
      }
    },
    onDone: () {
      log.fine('Port Scan completed');
    },
  ); // Don't forget to cancel the stream when not in use.

  const String target = '192.168.1.1';
  PortScanner.scanPortsForSingleDevice(
    target,
    // Scan will start from this port.
    // startPort: 1,
    endPort: 9400,
    progressCallback: (progress) {
      log.finer('Progress for port discovery : $progress');
    },
  ).listen(
    (activeHost) {
      final OpenPort deviceWithOpenPort = activeHost.openPort[0];

      if (deviceWithOpenPort.isOpen) {
        log.fine('Found open port: ${deviceWithOpenPort.port}');
      }
    },
    onDone: () {
      log.fine('Port Scan from 1 to 9400 completed');
    },
  );
}
