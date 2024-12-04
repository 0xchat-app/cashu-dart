
import 'package:cashu_dart/utils/database/db_isar.dart';

import '../../core/nuts/token/proof_isar.dart';

class ProofStore {
  static Future<bool> addProofs(List<ProofIsar> proofs) async {
    if (proofs.isEmpty) return true;

    await CashuIsarDB.putAll(proofs);
    return true;
  }

  static Future<List<ProofIsar>> getProofs({List<String> ids = const [], String c = ''}) async {
    return CashuIsarDB.query<ProofIsar>().filter()
        .optional(ids.isNotEmpty,
            (q) => q.anyOf(ids,
                    (q, element) => q.keysetIdEqualTo(element)))
        .optional(c.isNotEmpty,
            (q) => q.cEqualTo(c))
        .findAll();
  }

  static Future<bool> deleteProofs(List<ProofIsar> delProofs) async {
    if (delProofs.isEmpty) return true;

    final deleted = await CashuIsarDB.delete<ProofIsar>((collection) =>
        collection.filter()
            .anyOf(delProofs,
                (q, delProof) => q
                .secretEqualTo(delProof.secret)
                .and()
                .keysetIdEqualTo(delProof.keysetId))
            .deleteAll()
    );
    return deleted == delProofs.length;
  }
}