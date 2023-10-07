import 'package:network_tools/src/mdns_scanner/get_srv_list_by_os/srv_list_linux.dart';
import 'package:universal_io/io.dart';

/// This class is common interface for executing functions on different os
class SrvList {
  /// Will get the srv record in the local network.
  static Future<List<String>?> getSrvRecordList() async {
    if (Platform.isLinux) {
      return SrvListLinux.getSrvRecordList();
    }
    // else if (Platform.isMacOS){
    //   // I think the command should be dns-sd so
    //   // dns-sd -B _services._dns-sd._udp local.
    //   // and
    //   // dns-sd -B _ipp._tcp local.
    // }

    // Get srv record list is not supported on this os
    return [];
  }
}
