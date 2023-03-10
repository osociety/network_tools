import 'package:network_tools/network_tools.dart';

const testPort =
    22; //ssh (22) is for github actions and dns (53) for local machine
const testTimeout = Duration(milliseconds: 2000);
int testLastHostId(String subnet) => HostScanner.getMaxHost(subnet) ~/ 4;
