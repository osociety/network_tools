import 'package:logging/logging.dart';
import 'package:network_tools/network_tools.dart';

final log = Logger("network_tools");
const testPort =
    22; //ssh (22) is for github actions and dns (53) for local machine
const testTimeout = Duration(milliseconds: 2000);
int testLastHostId(String subnet) => HostScanner.getMaxHost(subnet);
