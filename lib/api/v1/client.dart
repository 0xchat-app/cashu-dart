
import 'package:bolt11_decoder/bolt11_decoder.dart';

import '../../business/proof/proof_helper.dart';
import '../../business/transaction/transaction_helper.dart';
import '../../business/wallet/cashu_manager.dart';
import '../../core/nuts/v1/nut_05.dart';
import '../../core/nuts/v1/nut_08.dart';
import '../../model/mint_model.dart';

class CashuAPIV1Client {

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

    if (pr.isEmpty) return false;

    // Get quote ID.
    final quoteResponse = await Nut5.requestMeltQuote(
      mintURL: mint.mintURL,
      request: pr,
    );
    if (!quoteResponse.isSuccess || quoteResponse.data.quote.isEmpty) return false;
    final quoteID = quoteResponse.data.quote;

    // Get fee.
    final quoteInfoResponse = await Nut5.checkMintQuoteState(
      mintURL: mint.mintURL,
      quoteID: quoteID,
    );
    if (!quoteInfoResponse.isSuccess) return false;
    final fee = int.parse(quoteInfoResponse.data.fee);

    // Get proofs for pay.
    final req = Bolt11PaymentRequest(pr);
    final amount = req.amount.toBigInt().toInt();
    final response = await ProofHelper.getProofsToUse(
      mint: mint,
      amount: BigInt.from(amount + fee),
    );
    if (!response.isSuccess) return false;

    final proofs = response.data;
    final (paid, preimage) = await TransactionHelper.payingTheQuote(
      mint: mint,
      paymentKey: quoteID,
      proofs: proofs,
      fee: fee,
      meltAction: Nut8.payingTheQuote,
    );
    if (paid) {
      await CashuManager.shared.updateMintBalance(mint);
    }
    return paid;
  }
}