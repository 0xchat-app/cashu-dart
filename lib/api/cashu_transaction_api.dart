
import '../business/proof/proof_helper.dart';
import '../business/transaction/transaction_helper.dart';
import '../business/wallet/cashu_manager.dart';
import '../core/nuts/nut_00.dart';
import '../core/nuts/nut_07.dart';
import '../model/mint_model.dart';


class CashuTransactionAPI {

  static Future<String?> sendEcash({
    required IMint mint,
    required int amount,
  }) async {

    await CashuManager.shared.setupFinish.future;

    // get proofs
    final payload = await ProofHelper.getProofsToUse(
      mintURL: mint.mintURL,
      amount: BigInt.from(amount),
    );
    if (payload == null) return null;

    final (proofs, _) = payload;
    final useProofs = <Proof>[];
    final totalAmount = proofs.fold(0, (pre, proof) => pre + proof.amountNum);

    if (totalAmount == amount) {
      useProofs.addAll(proofs);
    } else {
      final newProofs = await TransactionHelper.swapProofs(
        mint: mint,
        proofs: proofs,
        supportAmount: amount,
      );

      final payload = await ProofHelper.getProofsToUse(
        mintURL: mint.mintURL,
        amount: BigInt.from(amount),
      );
      if (payload == null) return null;
      final (actProofs, _) = payload;
      useProofs.addAll(actProofs);
    }

    if (useProofs.isEmpty) return null;

    final token = Token(
      token: [TokenEntry(mint: mint.mintURL, proofs: useProofs)],
      memo: memo.isNotEmpty ? memo : 'Sent via eNuts.',
    );
    final encodedToken =
    if (returnChange.isNotEmpty) {
      await CashuTokenHelper.addToken();
    }

    await ProofStore.deleteProofs(proofs);
    return CashuTokenHelper.getEncodedToken(
      ,
    );

  }
}