import 'package:logging/logging.dart';

final log = Logger("network_tools");
final examplesLog = Logger("network_tools_examples");

void enableExampleLogging() {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((record) {
    if (record.loggerName == examplesLog.name) {
      // ignore: avoid_print
      print(
        '${record.time.toLocal()}: ${record.level.name}: ${record.loggerName}: ${record.message}',
      );
    }
  });
}
