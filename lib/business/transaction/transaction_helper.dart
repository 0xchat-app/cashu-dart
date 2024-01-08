
import '../../core/DHKE_helper.dart';
import '../../core/keyset_store.dart';
import '../../core/nuts/DHKE.dart';
import '../../core/nuts/define.dart';
import '../../core/nuts/nut_00.dart';
import '../../model/history_entry.dart';
import '../../model/invoice.dart';
import '../../model/keyset_info.dart';
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
    required Future<CashuResponse<Receipt>> Function({
      required String mintURL,
      required int amount,
    }) createQuoteAction,
  }) async {
    final response = await createQuoteAction(
      mintURL: mint.mintURL,
      amount: amount,
    );
    if (!response.isSuccess) return null;
    await InvoiceStore.addInvoice(response.data);
    CashuManager.shared.invoiceHandler.addInvoice(response.data);
    return response.data;
  }

  static Future<List<Proof>?> requestTokensFromMint({
    required IMint mint,
    required String quoteID,
    required int amount,
    String unit = 'sat',
    required Future<CashuResponse<List<BlindedSignature>>> Function({
      required String mintURL,
      required String quote,
      required List<BlindedMessage> blindedMessages,
    }) requestTokensAction,
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
    if (keysetInfo == null || keyset.isEmpty) return null;

    // create blinded messages
    final ( blindedMessages, secrets, rs, _ ) =
    DHKEHelper.createBlindedMessages(
      keysetId: keysetInfo.id,
      amount: amount,
    );

    // request token
    final response = await requestTokensAction(
      mintURL: mint.mintURL,
      quote: quoteID,
      blindedMessages: blindedMessages,
    );
    if (!response.isSuccess) return null;

    // unblinding
    final proofs = await DHKE.constructProofs(
      promises: response.data,
      rs: rs,
      secrets: secrets,
      keysFetcher: (keysetId) => KeysetHelper.keysetFetcher(mint, unit, keysetId),
    );

    if (proofs != null) {
      await ProofStore.addProofs(proofs);
      await CashuManager.shared.updateMintBalance(mint);
    }

    return proofs;
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
      inputs: [...proofs],
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
    await ProofHelper.deleteProofs(proofs: [...proofs], mintURL: mint.mintURL);

    final amount = newProofs.totalAmount;
    await HistoryStore.addToHistory(
      amount: amount,
      type: IHistoryType.lnInvoice,
      value: paymentKey,
      mints: [mint.mintURL],
    );

    return (
      paid,
      preimage,
    );
  }
}