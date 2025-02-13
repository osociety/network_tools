import 'package:logging/logging.dart';

final examplesLogger = Logger("network_tools_examples");

void enableExampleLogging() {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((record) {
    if (record.loggerName == examplesLogger.name) {
      // ignore: avoid_print
      print(
        '${record.time.toLocal()}: ${record.level.name}: ${record.loggerName}: ${record.message}',
      );
    }
  });
}
