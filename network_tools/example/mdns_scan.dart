import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/mdns_scanner.dart';
import 'package:network_tools/src/models/mdns_info.dart';

Future<void> main() async {
  for (final ActiveHost activeHost in await MdnsScanner.searchMdnsDevices()) {
    final MdnsInfo? mdnsInfo = activeHost.mdnsInfo;
    print(
      'IP: ${activeHost.ip}, Port: ${mdnsInfo!.mdnsPort}, ServiceType: ${mdnsInfo.mdnsServiceType}, MdnsName: ${mdnsInfo.getOnlyTheStartOfMdnsName()}',
    );
  }
}
