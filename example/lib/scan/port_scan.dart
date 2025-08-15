import 'package:network_tools/network_tools.dart';

import '../example_utils.dart';

Future<void> main() async {
  enableExampleLogging();
  await configureNetworkTools('build');

  String subnet = '192.168.0'; //Default network id for home networks

  final interface = await NetInterface.localInterface();
  final netId = interface?.networkId;
  if (netId != null) {
    subnet = netId;
    examplesLogger.fine('subnet id $subnet');
  }

  // [New] Scan for a single open port in a subnet
  // You can set [firstHostId] and scan will start from this host in the network.
  // Similarly set [lastHostId] and scan will end at this host in the network.
  final stream2 = HostScannerService.instance.scanDevicesForSinglePort(
    subnet,
    53,
    progressCallback: (progress) {
      examplesLogger.finer('Progress for port discovery on host : $progress');
    },
  );

  stream2.listen(
    (ActiveHost activeHost) {
      examplesLogger.fine(
        '[scanDevicesForSinglePort]: Found device : $activeHost',
      );
      final OpenPort deviceWithOpenPort = activeHost.openPorts[0];
      if (deviceWithOpenPort.isOpen) {
        examplesLogger.fine(
          '[scanDevicesForSinglePort]: Found open port: ${deviceWithOpenPort.port} on ${activeHost.address}',
        );
      }
    },
    onDone: () {
      examplesLogger.fine('Port Scan completed');
    },
  ); // Don't forget to cancel the stream when not in use.

  String target = '192.168.1.1';
  final addr = interface?.ipAddress;
  if (addr != null) {
    target = addr;
    examplesLogger.fine("Target is $target");
  }

  PortScannerService.instance
      .scanPortsForSingleDevice(
        target,
        // Scan will start from this port.
        // startPort: 1,
        endPort: 9400,
        progressCallback: (progress) {
          examplesLogger.finer('Progress for port discovery : $progress');
        },
      )
      .listen(
        (activeHost) {
          final OpenPort deviceWithOpenPort = activeHost.openPorts[0];

          if (deviceWithOpenPort.isOpen) {
            examplesLogger.fine(
              'Found open port: ${deviceWithOpenPort.port} on device $target',
            );
          }
        },
        onDone: () {
          examplesLogger.fine('Port Scan from 1 to 9400 completed');
        },
      );
}
