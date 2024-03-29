
import 'package:bolt11_decoder/bolt11_decoder.dart';

import '../../business/proof/proof_helper.dart';
import '../../business/transaction/transaction_helper.dart';
import '../../business/wallet/cashu_manager.dart';
import '../../core/nuts/v0/nut_05.dart';
import '../../core/nuts/v0/nut_08.dart';
import '../../model/mint_model.dart';

class CashuAPIV0Client {

  /// Processes payment of a Lightning invoice.
  /// [mint]: The mint to use for payment.
  /// [pr]: The payment request string of the Lightning invoice.
  /// [amount]: The amount to pay.
  /// Returns true if payment is successful.
  static Future<bool> payingLightningInvoice({
    required IMint mint,
    required String pr,
  }) async {

    await CashuManager.shared.setupFinish.future;

    // Get fee
    final checkResponse = await Nut5.checkingLightningFees(mintURL: mint.mintURL, pr: pr);
    if (!checkResponse.isSuccess) return false;
    final fee = checkResponse.data;

    // Get amount
    final req = Bolt11PaymentRequest(pr);
    final amount = (req.amount.toDouble() * 100000000).toInt();

    final proofsResponse = await ProofHelper.getProofsToUse(
      mint: mint,
      amount: BigInt.from(amount + fee),
    );
    if (!proofsResponse.isSuccess) return false;

    final proofs = proofsResponse.data;
    final (paid, preimage) = await TransactionHelper.payingTheQuote(
      mint: mint,
      paymentKey: pr,
      proofs: proofs,
      fee: fee,
      meltAction: Nut8.payingTheInvoice,
    );

    if (paid) {
      await CashuManager.shared.updateMintBalance(mint);
    }

    return paid;
  }
}