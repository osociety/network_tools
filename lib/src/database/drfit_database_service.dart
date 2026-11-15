import 'package:injectable/injectable.dart';
import 'package:network_tools/src/database/database_service.dart';
import 'package:network_tools/src/database/drift_database.dart';
import 'package:network_tools/src/network_tools_utils.dart';

@Injectable(as: DatabaseService<AppDatabase>)
class DriftDatabaseService extends DatabaseService<AppDatabase> {
  static AppDatabase? appDatabase;
  static Future<AppDatabase?>? _openFuture;

  @override
  Future<AppDatabase?> open() => _openFuture ??= _open();

  /// Forgets the cached connection so the next [open] builds a fresh database.
  ///
  /// A drift connection cannot be reopened once closed, so without this the
  /// package stays broken for the rest of the process after a shutdown.
  static void reset() {
    _openFuture = null;
    appDatabase = null;
  }

  static Future<AppDatabase?> _open() async {
    final AppDatabase database = appDatabase ??= AppDatabase();
    try {
      await database.ensureIndexes();
    } catch (error, stackTrace) {
      // Indexes only speed up lookups, so a failure here must not block the
      // repositories from starting.
      logger.warning(
        'Failed to create database indexes: $error',
        error,
        stackTrace,
      );
    }
    return database;
  }
}
