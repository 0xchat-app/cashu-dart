
import 'package:bolt11_decoder/bolt11_decoder.dart';

import '../../business/proof/proof_helper.dart';
import '../../business/proof/token_helper.dart';
import '../../business/transaction/hitstory_store.dart';
import '../../business/transaction/transaction_helper.dart';
import '../../business/wallet/cashu_manager.dart';
import '../../core/nuts/nut_00.dart';
import '../../core/nuts/v0/nut.dart';
import '../../model/history_entry.dart';
import '../../model/invoice.dart';
import '../../model/mint_model.dart';
import '../../utils/network/response.dart';

class CashuTransactionAPI {
  /// Redeems e-cash from the given string.
  /// [ecashString]: The string representing the e-cash.
  /// Returns a tuple containing memo and amount if successful.
  static Future<CashuResponse<(String memo, int amount)>> redeemEcash(String ecashString) async {
    await CashuManager.shared.setupFinish.future;
    final token = TokenHelper.getDecodedToken(ecashString);
    if (token == null) return CashuResponse.fromErrorMsg('Invalid token');
    if (token.unit.isNotEmpty && token.unit != 'sat') return CashuResponse.fromErrorMsg('Unsupported unit');

    final memo = token.memo;
    var receiveAmount = 0;
    final mints = <String>{};

    final tokenEntry = token.token;

    return Future<CashuResponse<(String memo, int amount)>>(() async {
      for (var entry in tokenEntry) {
        final mint = await CashuManager.shared.getMint(entry.mint);
        if (mint == null) continue ;

        final response = await ProofHelper.swapProofs(
          mint: mint,
          proofs: entry.proofs,
          swapAction: Nut6.split,
        );
        if (!response.isSuccess) return response.cast();

        final newProofs = response.data;
        receiveAmount += newProofs.totalAmount;
        mints.add(mint.mintURL);
        await CashuManager.shared.updateMintBalance(mint);
      }

      if (receiveAmount > 0) {
        return CashuResponse.fromSuccessData((memo, receiveAmount));
      } else {
        return CashuResponse.fromErrorMsg('No funds available proofs for redemption.');
      }
    }).whenComplete(() {
      if (receiveAmount > 0) {
        HistoryStore.addToHistory(
          amount: receiveAmount,
          type: IHistoryType.eCash,
          value: ecashString,
          mints: mints.toList(),
        );
      }
    });
  }

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

  /// Creates a Lightning invoice with the given amount.
  /// [mint]: The mint to issue the invoice.
  /// [amount]: The amount for the invoice.
  /// Returns the created invoice object if successful, otherwise null.
  static Future<Receipt?> createLightningInvoice({
    required IMint mint,
    required int amount,
  }) async {
    return TransactionHelper.requestCreateInvoice(
      mint: mint,
      amount: amount,
      createQuoteAction: Nut3.requestMintInvoice,
    );
  }
}