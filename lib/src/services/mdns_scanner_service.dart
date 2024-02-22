import 'package:multicast_dns/multicast_dns.dart';
import 'package:network_tools/network_tools.dart';
import 'package:universal_io/io.dart';

abstract class MdnsScannerService {
  MdnsScannerService() {
    _instance = this;
  }

  static late MdnsScannerService _instance;

  static MdnsScannerService get instance => _instance;

  /// This method searching for all the mdns devices in the network.
  Future<List<ActiveHost>> searchMdnsDevices({
    bool forceUseOfSavedSrvRecordList = false,
  });

  Future<List<ActiveHost>> findingMdnsWithAddress(
    String serviceType,
  );

  Future<List<ActiveHost>> findAllActiveHostForSrv({
    required InternetAddress addressType,
    required MDnsClient client,
    required PtrResourceRecord ptr,
    required SrvResourceRecord srv,
  });

  ActiveHost convertSrvToHostName({
    required InternetAddress internetAddress,
    required PtrResourceRecord ptr,
    required SrvResourceRecord srv,
  });
}
