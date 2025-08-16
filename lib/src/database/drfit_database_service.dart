import 'package:injectable/injectable.dart';
import 'package:network_tools/src/database/database_service.dart';
import 'package:network_tools/src/database/drift_database.dart';

@Injectable(as: DatabaseService<AppDatabase>)
class DriftDatabaseService extends DatabaseService<AppDatabase> {
  static AppDatabase? appDatabase;
  @override
  Future<AppDatabase?> open() async {
    return appDatabase ??= AppDatabase();
  }
}
