
import '../../core/DHKE_helper.dart';
import '../../core/mint_actions.dart';
import '../../core/nuts/DHKE.dart';
import '../../core/nuts/define.dart';
import '../../core/nuts/nut_00.dart';
import '../../model/history_entry.dart';
import '../../model/invoice.dart';
import '../../model/mint_model.dart';
import '../../utils/network/response.dart';
import '../mint/mint_helper.dart';
import '../proof/keyset_helper.dart';
import '../proof/proof_helper.dart';
import '../proof/proof_store.dart';
import '../wallet/cashu_manager.dart';
import 'hitstory_store.dart';
import 'invoice_store.dart';

typedef PayingTheInvoiceResponse = (
  bool paid,
  String preimage,
);

class TransactionHelper {

  static Future<Receipt?> requestCreateInvoice({
    required IMint mint,
    required int amount,
  }) async {
    final response = await mint.createQuoteAction(
      mintURL: mint.mintURL,
      amount: amount,
    );
    if (!response.isSuccess) return null;
    await InvoiceStore.addInvoice(response.data);
    CashuManager.shared.invoiceHandler.addInvoice(response.data);
    return response.data;
  }

  static Future<CashuResponse<List<Proof>>> requestTokensFromMint({
    required IMint mint,
    required String quoteID,
    required int amount,
    String unit = 'sat',
  }) async {
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
    final keysetInfo = await KeysetHelper.tryGetMintKeysetInfo(mint, unit);
    final keyset = keysetInfo?.keyset ?? {};
    if (keysetInfo == null || keyset.isEmpty) {
      return CashuResponse.fromErrorMsg('Keyset is empty.');
    }

    // create blinded messages
    final ( blindedMessages, secrets, rs, _ ) =
    DHKEHelper.createBlindedMessages(
      keysetId: keysetInfo.id,
      amount: amount,
    );

    // request token
    final response = await mint.requestTokensAction(
      mintURL: mint.mintURL,
      quote: quoteID,
      blindedMessages: blindedMessages,
    );
    if (!response.isSuccess) {
      if (response.errorMsg.contains('keyset id unknown')) {
        MintHelper.updateMintKeysetFromRemote(mint);
      } else if (response.errorMsg.contains('quote already issued')) {
        return CashuResponse.fromSuccessData([]);
      }
      return response.cast();
    }

    // unblinding
    final proofs = await DHKE.constructProofs(
      promises: response.data,
      rs: rs,
      secrets: secrets,
      keysFetcher: (keysetId) => KeysetHelper.keysetFetcher(mint, unit, keysetId),
    );

    if (proofs == null) {
      return CashuResponse.fromErrorMsg('Unblinding error.');
    }

    await ProofStore.addProofs(proofs);
    await CashuManager.shared.updateMintBalance(mint);

    return CashuResponse.fromSuccessData(proofs);
  }

  static Future<PayingTheInvoiceResponse> payingTheQuote({
    required IMint mint,
    String paymentKey = '',
    required List<Proof> proofs,
    String unit = 'sat',
    required int fee,
    required Future<CashuResponse<MeltResponse>> Function({
      required String mintURL,
      required String quote,
      required List<Proof> inputs,
      required List<BlindedMessage> outputs,
    }) meltAction,
  }) async {

    proofs = [...proofs];
    const failResult = (false, '');

    // get keyset
    final keysetInfo = await KeysetHelper.tryGetMintKeysetInfo(mint, unit);
    final keyset = keysetInfo?.keyset ?? {};
    if (keysetInfo == null || keyset.isEmpty) return failResult;

    // create outputs
    final ( blindedMessages, secrets, rs, _ ) =
    DHKEHelper.createBlankOutputs(
      keysetId: keysetInfo.id,
      amount: fee,
    );

    // melt token
    final response = await meltAction(
      mintURL: mint.mintURL,
      quote: paymentKey,
      inputs: proofs,
      outputs: blindedMessages,
    );
    if (!response.isSuccess) return failResult;

    // unbinding
    final ( paid, preimage, change ) = response.data;
    final newProofs = await DHKE.constructProofs(
      promises: change,
      rs: rs,
      secrets: secrets,
      keysFetcher: (keysetId) => KeysetHelper.keysetFetcher(mint, unit, keysetId),
    );
    if (newProofs == null) return failResult;

    await ProofStore.addProofs([...newProofs]);
    await ProofHelper.deleteProofs(proofs: proofs, mint: mint);

    final amount = newProofs.totalAmount - proofs.totalAmount;
    await HistoryStore.addToHistory(
      amount: amount,
      type: IHistoryType.lnInvoice,
      value: paymentKey,
      mints: [mint.mintURL],
      fee: fee,
    );

    return (
      paid,
      preimage,
    );
  }
}