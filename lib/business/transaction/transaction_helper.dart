
import 'package:cashu_dart/business/proof/proof_helper.dart';
import 'package:cashu_dart/business/transaction/invoice_store.dart';
import 'package:cashu_dart/business/wallet/cashu_manager.dart';

import '../../core/DHKE_helper.dart';
import '../../core/keyset_store.dart';
import '../../core/nuts/DHKE.dart';
import '../../core/nuts/nut_00.dart';
import '../../core/nuts/v1/nut_03.dart';
import '../../core/nuts/v1/nut_04.dart';
import '../../core/nuts/v1/nut_05.dart';
import '../../core/nuts/v1/nut_08.dart';
import '../../model/invoice.dart';
import '../../model/keyset_info.dart';
import '../../model/mint_model.dart';
import '../mint/mint_helper.dart';
import '../proof/proof_store.dart';

typedef PayingTheInvoiceResponse = (
  bool paid,
  String preimage,
);

class TransactionHelper {

  /// Obtain the keyset of mint corresponding to the unit.
  /// If the local data is not available, obtain it from the remote endpoint
  static Future<KeysetInfo?> tryGetMintKeysetInfo(IMint mint, String unit) async {
    final keysetId = mint.keysetId(unit);
    // from local
    final keysets = await KeysetStore.getKeyset(mintURL: mint.mintURL, id: keysetId);
    var keysetInfo = keysets.where((element) => element.active && element.unit == unit).firstOrNull;

    if (keysetInfo == null) {
      // from remote
      final newKeysets = await MintHelper.fetchKeysetFromRemote(mint.mintURL);
      keysetInfo = newKeysets.where((element) => element.unit == unit).firstOrNull;
    }
    if (keysetInfo == null) return null;

    // update mint keysetId
    if (keysetInfo.keyset.isNotEmpty) {
      mint.updateKeysetId(keysetInfo.id, unit);
    }

    return keysetInfo;
  }

  static Future<Receipt?> requestCreateInvoice({
    required IMint mint,
    required int amount,
    Future<Receipt?> Function({
      required String mintURL,
      required int amount,
    })? createQuoteAction,
  }) async {
    createQuoteAction ??= Nut4.requestMintQuote;
    final invoice = await createQuoteAction(
      mintURL: mint.mintURL,
      amount: amount,
    );
    if (invoice == null) return null;
    await InvoiceStore.addInvoice(invoice);
    CashuManager.shared.invoiceHandler.addInvoice(invoice);
    return invoice;
  }

  static Future<List<Proof>?> requestTokensFromMint({
    required IMint mint,
    required String quoteID,
    required int amount,
    String unit = 'sat',
    Future<List<BlindedSignature>?> Function({
      required String mintURL,
      required String quote,
      required List<BlindedMessage> blindedMessages,
    })? requestTokensAction,
  }) async {

    requestTokensAction ??= Nut4.requestTokensFromMint;
    // // check quote state
    // final quoteInfo = await Nut4.checkMintQuoteState(
    //   mintURL: mint.mintURL,
    //   quoteID: quoteID,
    // );
    // if (quoteInfo == null) return null;
    // final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // final isTimeout = quoteInfo.expiry > 0 && quoteInfo.expiry < now;
    // if (isTimeout || quoteInfo.paid) return null;

    // get keyset
    final keysetInfo = await tryGetMintKeysetInfo(mint, unit);
    final keyset = keysetInfo?.keyset ?? {};
    if (keysetInfo == null || keyset.isEmpty) return null;

    // create blinded messages
    final ( blindedMessages, secrets, rs, _ ) =
    DHKEHelper.createBlindedMessages(
      keysetId: keysetInfo.id,
      amount: amount,
    );

    // request token
    final promises = await requestTokensAction(
      mintURL: mint.mintURL,
      quote: quoteID,
      blindedMessages: blindedMessages,
    );
    if (promises == null) return null;

    // unblinding
    final proofs = DHKE.constructProofs(
      promises: promises,
      rs: rs,
      secrets: secrets,
      keys: keyset,
    );

    if (proofs != null) {
      await ProofStore.addProofs(proofs);
      await CashuManager.shared.updateMintBalance(mint);
    }

    return proofs;
  }

  static Future<PayingTheInvoiceResponse> payingTheQuote({
    required IMint mint,
    String request = '',
    String quoteID = '',
    required List<Proof> proofs,
    String unit = 'sat',
    int? fee,
  }) async {

    const failResult = (false, '');

    if (quoteID.isEmpty) {
      if (request.isEmpty) return failResult;
      final payload = await Nut5.requestMeltQuote(
        mintURL: mint.mintURL,
        request: request,
      );
      if (payload == null || payload.quote.isEmpty) return failResult;
      quoteID = payload.quote;
    }

    // update fee if null
    if (fee == null) {
      final quoteInfo = await Nut5.checkMintQuoteState(
        mintURL: mint.mintURL,
        quoteID: quoteID,
      );
      if (quoteInfo == null) return failResult;
      fee = int.parse(quoteInfo.fee);
    }

    // get keyset
    final keysetInfo = await tryGetMintKeysetInfo(mint, unit);
    final keyset = keysetInfo?.keyset ?? {};
    if (keysetInfo == null || keyset.isEmpty) return failResult;

    // create outputs
    final ( blindedMessages, secrets, rs, _ ) =
    DHKEHelper.createBlankOutputs(
      keysetId: keysetInfo.id,
      amount: fee,
    );

    // melt token
    final response = await Nut8.payingTheQuote(
      mintURL: mint.mintURL,
      quote: quoteID,
      inputs: proofs,
      outputs: blindedMessages,
    );
    if (response == null) return failResult;

    // unbinding
    final ( paid, preimage, change ) = response;
    final newProofs = DHKE.constructProofs(
      promises: change,
      rs: rs,
      secrets: secrets,
      keys: keyset,
    ) ?? [];

    await ProofStore.addProofs(newProofs);
    ProofHelper.deleteProofs(proofs: proofs, mintURL: mint.mintURL);

    return (
      paid,
      preimage,
    );
  }

  static Future<List<Proof>> swapProofs({
    required IMint mint,
    required List<Proof> proofs,
    int? supportAmount,
    String unit = 'sat',
  }) async {

    // get keyset
    final keysetInfo = await tryGetMintKeysetInfo(mint, unit);
    final keyset = keysetInfo?.keyset ?? {};
    if (keysetInfo == null || keyset.isEmpty) return proofs;

    final proofsTotalAmount = proofs.fold<BigInt>(BigInt.zero, (pre, proof) {
      final amount = BigInt.tryParse(proof.amount) ?? BigInt.zero;
      return pre + amount;
    });

    final amount = supportAmount ?? proofsTotalAmount.toInt();
    List<BlindedMessage> blindedMessages = [];
    List<String> secrets = [];
    List<BigInt> rs = [];
    {
      final ( $1, $2, $3, _ ) = DHKEHelper.createBlindedMessages(
        keysetId: keysetInfo.id,
        amount: amount,
      );
      blindedMessages.addAll($1);
      secrets.addAll($2);
      rs.addAll($3);
    }
    {
      final ( $1, $2, $3, _ ) = DHKEHelper.createBlindedMessages(
        keysetId: keysetInfo.id,
        amount: proofsTotalAmount.toInt() - amount,
      );
      blindedMessages.addAll($1);
      secrets.addAll($2);
      rs.addAll($3);
    }

    final promises = await Nut3.swap(
      mintURL: mint.mintURL,
      proofs: proofs,
      outputs: blindedMessages,
    ) ?? [];

    final newProofs = DHKE.constructProofs(
      promises: promises,
      rs: rs,
      secrets: secrets,
      keys: keyset,
    ) ?? [];

    await ProofStore.addProofs(newProofs);
    ProofHelper.deleteProofs(proofs: proofs, mintURL: mint.mintURL);
    return newProofs;
  }
}