
import 'package:cashu_dart/business/mint/mint_store.dart';
import 'package:cashu_dart/business/proof/proof_store.dart';
import 'package:cashu_dart/utils/tools.dart';

import '../../core/nuts/nut_00.dart';

class ProofStoreHelper {
  static Future<List<Proof>> getProofsToUse({
    required String mintURL,
    required BigInt amount,
    bool orderAsc = false
  }) async {

    final mintIds = (await MintStore.getMintIdsByUrl(mintURL)).map((e) => e.id).toList();
    final usableProofs = await ProofStore.getProofs(ids: mintIds);
    final List<Proof> proofsToSend = [];
    BigInt amountAvailable = BigInt.zero;

    if (orderAsc) {
      usableProofs.sort((a, b) => a.amount.compareTo(b.amount));
    } else {
      usableProofs.sort((a, b) => b.amount.compareTo(a.amount));
    }

    for (final proof in usableProofs) {
      if (amountAvailable >= amount) break;
      amountAvailable += proof.amount.asBigInt();
      proofsToSend.add(proof);
    }

    return proofsToSend;
  }

}