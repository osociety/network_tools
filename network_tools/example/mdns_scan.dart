import 'package:network_tools/network_tools.dart';

Future<void> main() async {
  for (final ActiveHost activeHost in await MdnsScanner.searchMdnsDevices()) {
    final MdnsInfo? mdnsInfo = activeHost.mdnsInfo;
    print(
      'IP: ${activeHost.ip}, Port: ${mdnsInfo!.mdnsPort}, ServiceType: ${mdnsInfo.mdnsServiceType}, MdnsName: ${mdnsInfo.getOnlyTheStartOfMdnsName()}',
    );
  }
}
