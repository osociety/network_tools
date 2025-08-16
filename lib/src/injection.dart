import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:network_tools/src/injection.config.dart';

final getIt = GetIt.instance;

/// Saves the current environment for manual use
late String currentEnv;

@injectableInit
void configureDependencies(String env) {
  currentEnv = env;
  GetIt.instance.init(environment: env);
}

abstract class Env {
  static const String test = 'test';
  static const String dev = 'dev';
  static const String prod = 'prod';

  /// Demo of the app with fake data
  static const String demo = 'demo';
}
