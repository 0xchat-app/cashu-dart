
import 'package:cashu_dart/utils/list_extension.dart';

import '../../core/nuts/nut_00.dart';
import '../../utils/database/db.dart';

class ProofStore {
  static Future<bool> addProofs(List<Proof> proofs) async {
    if (proofs.isEmpty) return true;
    List<bool> results = [];
    for (var chunk in proofs.toChunks(100)) {
      results.add(await _addProofs(chunk));
    }
    return results.every((x) => x);
  }

  static Future<bool> _addProofs(List<Proof> proofs) async {
    if (proofs.isEmpty) return true;
    final rowsAffected = await CashuDB.sharedInstance.insertObjects<Proof>(proofs);
    return rowsAffected == proofs.length;
  }

  static Future<List<Proof>> getProofs({List<String> ids = const []}) async {
    if (ids.isNotEmpty) {
      final quotedIds = ids.map((e) => '"$e"').toList().join(',');
      return CashuDB.sharedInstance.objects<Proof>(
        where: ' id in ($quotedIds) ',
      );
    } else {
      return CashuDB.sharedInstance.objects<Proof>();
    }
  }

  static Future<bool> deleteProofs(List<Proof> delProofs) async {
    if (delProofs.isEmpty) return true;

    var rowsAffected = 0;

    final map = delProofs.groupBy((e) => e.id);
    await Future.forEach(map.keys, (id) async {
      final proofs = map[id] ?? [];
      final secrets = proofs.map((e) => '"${e.secret}"').toList().join(',');
      rowsAffected += await CashuDB.sharedInstance.delete<Proof>(
        where: ' id = ? and secret in ($secrets)',
        whereArgs: [id],
      );
    });

    return rowsAffected == delProofs.length;
  }
}