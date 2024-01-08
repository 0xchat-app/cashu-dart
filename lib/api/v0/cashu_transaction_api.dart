
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
import 'cashu_mint_api.dart';

class CashuTransactionAPI {
  /// Sends e-cash using the provided mint and amount.
  /// [mint]: The mint object to use for sending e-cash.
  /// [amount]: The amount of e-cash to send.
  /// [memo]: An optional memo for the transaction.
  /// Returns the encoded token if successful, otherwise null.
  static Future<String?> sendEcash({
    required IMint mint,
    required int amount,
    String memo = '',
    List<Proof>? proofs,
  }) async {
    await CashuManager.shared.setupFinish.future;

    // get proofs
    proofs ??= await ProofHelper.getProofsToUse(
      mintURL: mint.mintURL,
      amount: BigInt.from(amount),
    );
    if (proofs.isEmpty) return null;

    if (proofs.totalAmount != amount) {
      proofs = await ProofHelper.getProofsToUse(
        mintURL: mint.mintURL,
        amount: BigInt.from(amount),
        proofs: proofs,
      );
      if (proofs.isEmpty) return null;
    }

    final encodedToken = TokenHelper.getEncodedToken(
      Token(
        token: [TokenEntry(mint: mint.mintURL, proofs: proofs)],
        memo: memo.isNotEmpty ? memo : 'Sent via 0xChat.',
      )
    );

    await HistoryStore.addToHistory(
      amount: -amount,
      type: IHistoryType.eCash,
      value: encodedToken,
      mints: [mint.mintURL],
    );

    await ProofHelper.deleteProofs(proofs: proofs, mintURL: null);
    await CashuManager.shared.updateMintBalance(mint);

    print('[I][Cashu - sendEcash] Create Ecash: $encodedToken');
    return encodedToken;
  }

  /// Redeems e-cash from the given string.
  /// [ecashString]: The string representing the e-cash.
  /// Returns a tuple containing memo and amount if successful, otherwise null.
  static Future<(String memo, int amount)?> redeemEcash(String ecashString) async {
    await CashuManager.shared.setupFinish.future;
    final token = TokenHelper.getDecodedToken(ecashString);
    if (token == null) return null;
    if (token.unit.isNotEmpty && token.unit != 'sat') return null;

    final memo = token.memo;
    var receiveAmount = 0;
    final mints = <String>{};

    final tokenEntry = token.token;
    for (var entry in tokenEntry) {
      var mint = await CashuManager.shared.getMint(entry.mint);
      if (mint == null) {
        try {
          mint = await CashuMintAPI.addMint(entry.mint);
        } catch (_) {
          continue ;
        }
      }
      if (mint == null) continue ;

      final newProofs = await ProofHelper.swapProofs(
        mint: mint,
        proofs: entry.proofs,
        swapAction: Nut6.split,
      );
      if (newProofs == null) return null;

      final receiveSuccess = newProofs != entry.proofs;
      if (receiveSuccess) {
        receiveAmount += newProofs.totalAmount;
        mints.add(mint.mintURL);
        await CashuManager.shared.updateMintBalance(mint);
      }
    }

    await HistoryStore.addToHistory(
      amount: receiveAmount,
      type: IHistoryType.eCash,
      value: ecashString,
      mints: mints.toList(),
    );

    if (receiveAmount > 0) {
      return (memo, receiveAmount);
    } else {
      return null;
    }
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
    final response = await Nut5.checkingLightningFees(mintURL: mint.mintURL, pr: pr);
    if (!response.isSuccess) return false;
    final fee = response.data;

    // Get amount
    final req = Bolt11PaymentRequest(pr);
    final amount = (req.amount.toDouble() * 100000000).toInt();

    final proofs = await ProofHelper.getProofsToUse(
      mintURL: mint.mintURL,
      amount: BigInt.from(amount + fee),
    );
    if (proofs.isEmpty) return false;

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