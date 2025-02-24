import 'package:network_tools/network_tools.dart';

import '../example_utils.dart';

Future<void> main() async {
  enableExampleLogging();
  await configureNetworkTools('build');
  for (final ActiveHost activeHost
      in await MdnsScannerService.instance.searchMdnsDevices()) {
    final MdnsInfo? mdnsInfo = await activeHost.mdnsInfo;
    examplesLogger.fine(
      'Address: ${activeHost.address}, Port: ${mdnsInfo!.mdnsPort}, ServiceType: ${mdnsInfo.mdnsServiceType}, MdnsName: ${mdnsInfo.getOnlyTheStartOfMdnsName()}, Mdns Device Name: ${mdnsInfo.mdnsSrvTarget}, TXT Record: ${mdnsInfo.textRecord}\n',
    );
  }
}
