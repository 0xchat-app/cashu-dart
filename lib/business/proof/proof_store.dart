
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
      return CashuDB.sharedInstance.objects<Proof>(
        where: ' id in (?) ',
        whereArgs: [ids.join(',')],
      );
    } else {
      return CashuDB.sharedInstance.objects<Proof>();
    }
  }

  static Future<bool> deleteProofs(List<Proof> proofs) async {
    if (proofs.isEmpty) return true;
    final ids = [];
    final secrets = [];
    for (final proof in proofs) {
      ids.add(proof.id);
      secrets.add(proof.secret);
    }
    final rowsAffected = await CashuDB.sharedInstance.delete<Proof>(
      where: ' id in (?) and secret in (?)',
      whereArgs: [ids.join(','), secrets.join(',')],
    );
    return rowsAffected == proofs.length;
  }
}