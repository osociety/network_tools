import 'package:network_tools/network_tools.dart';
import '../lib/src/network_tools_utils.dart';

Future<void> main() async {
  enableExampleLogging();
  await configureNetworkTools('build');
  for (final ActiveHost activeHost in await MdnsScanner.searchMdnsDevices()) {
    final MdnsInfo? mdnsInfo = await activeHost.mdnsInfo;
    examplesLog.fine(
      'Address: ${activeHost.address}, Port: ${mdnsInfo!.mdnsPort}, ServiceType: ${mdnsInfo.mdnsServiceType}, MdnsName: ${mdnsInfo.getOnlyTheStartOfMdnsName()}, Mdns Device Name: ${mdnsInfo.mdnsSrvTarget}\n',
    );
  }
}
