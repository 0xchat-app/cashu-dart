
import 'package:isar/isar.dart';

import '../../model/db_config_isar.dart';
import 'db_isar.dart';

class DBConfigHelper {

  static const String _migrationKey = 'dbMigrationCompleted';

  static Future<bool> isSqliteToIsarFinish() async {
    final config = await CashuIsarDB.shared.queryFirst<DBConfigIsar>(
      (query) {
        query.filter().keyEqualTo(_migrationKey);
        return query;
      },
    );
    return config != null && config.value.isNotEmpty;
  }

  static Future<void> setSqliteToIsarFinish() async {
    final config = DBConfigIsar(
      _migrationKey,
      '1',
    );
    await CashuIsarDB.shared.put<DBConfigIsar>(config);
  }
}