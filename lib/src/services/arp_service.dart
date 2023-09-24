import 'package:network_tools/src/models/arp_data.dart';

abstract class ARPService {
  Future<ARPService> open();
  Future<List<String?>?> entries();
  Future<ARPData?> entryFor(String address);
  Future<void> buildTable();
  void close();
}
