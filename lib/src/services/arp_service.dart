import 'package:network_tools/src/models/arp_data.dart';

abstract class ARPService {
  ARPService() {
    _instance = this;
  }

  static late ARPService _instance;

  static ARPService get instance => _instance;

  Future<ARPService> open();
  Future<List<String?>?> entries();
  Future<ARPData?> entryFor(String address);
  Future<void> buildTable();
  void close();
}
