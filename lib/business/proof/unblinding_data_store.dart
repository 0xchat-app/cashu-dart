
import 'package:cashu_dart/utils/list_extension.dart';

import '../../model/unblinding_data.dart';
import '../../utils/database/db.dart';

class UnblindingDataStore {
  static Future add(List<UnblindingData> list) async {
    await CashuDB.sharedInstance.insertObjects<UnblindingData>(list);
  }

  static Future<List<UnblindingData>> getData() async {
    return CashuDB.sharedInstance.objects<UnblindingData>();
  }

  static Future<bool> delete(List<UnblindingData> delData) async {
    if (delData.isEmpty) return true;

    var rowsAffected = 0;

    final map = delData.groupBy((e) => e.id);
    await Future.forEach(map.keys, (id) async {
      final unblindingDataList = map[id] ?? [];
      final placeholders = unblindingDataList.map((_) => '?').toList().join(',');
      final secrets = unblindingDataList.map((e) => e.secret).toList();
      rowsAffected += await CashuDB.sharedInstance.delete<UnblindingData>(
        where: ' id = ? and secret in ($placeholders)',
        whereArgs: [id, ...secrets],
      );
    });

    return rowsAffected == delData.length;
  }
}