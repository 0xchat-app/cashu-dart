
import 'package:cashu_dart/utils/list_extension.dart';

import '../../core/nuts/nut_00.dart';
import '../../utils/database/db.dart';

class ProofStore {
  static Future<bool> addProofs(List<Proof> proofs) async {
    if (proofs.isEmpty) return true;
    final rowsAffected = await CashuDB.sharedInstance.insertObjects<Proof>(proofs);
    return rowsAffected == proofs.length;
  }

  static Future<List<Proof>> getProofs({List<String> ids = const [], String c = ''}) async {
    final placeholders = ids.map((_) => '?').toList().join(',');
    final whereString = [
      if (ids.isNotEmpty) ' id in ($placeholders) ',
      if (c.isNotEmpty) ' C = ? ',
    ];
    final whereArgs = [
      if (ids.isNotEmpty) ...ids,
      if (c.isNotEmpty) c,
    ];
    return CashuDB.sharedInstance.objects<Proof>(
      where: whereString.isNotEmpty ? whereString.join('and') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
    );
  }

  static Future<bool> deleteProofs(List<Proof> delProofs) async {
    if (delProofs.isEmpty) return true;

    var rowsAffected = 0;

    final map = delProofs.groupBy((e) => e.id);
    await Future.forEach(map.keys, (id) async {
      final proofs = map[id] ?? [];
      final placeholders = proofs.map((_) => '?').toList().join(',');
      final secrets = proofs.map((e) => e.secret).toList();
      rowsAffected += await CashuDB.sharedInstance.delete<Proof>(
        where: ' id = ? and secret in ($placeholders)',
        whereArgs: [id, ...secrets],
      );
    });

    return rowsAffected == delProofs.length;
  }
}