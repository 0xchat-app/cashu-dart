
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
import '../wallet/ecash_manager.dart';
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
    final unblindingResponse = await EcashManager.shared.unblindingBlindedSignature((
      mint,
      unit,
      response.data,
      secrets,
      rs,
    ));
    if (!unblindingResponse.isSuccess) {
      return unblindingResponse;
    }

    return CashuResponse.fromSuccessData(unblindingResponse.data);
  }

  static Future<CashuResponse<MeltResponse>> payingTheQuote({
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

    // get keyset
    final keysetInfo = await KeysetHelper.tryGetMintKeysetInfo(mint, unit);
    final keyset = keysetInfo?.keyset ?? {};
    if (keysetInfo == null || keyset.isEmpty) return CashuResponse.fromErrorMsg('Keyset is empty');

    // create outputs
    final ( blindedMessages, secrets, rs, _ ) =
    DHKEHelper.createBlankOutputs(
      keysetId: keysetInfo.id,
      amount: fee,
    );

    // melt token
    final meltResponse = await meltAction(
      mintURL: mint.mintURL,
      quote: paymentKey,
      inputs: proofs,
      outputs: blindedMessages,
    );
    if (!meltResponse.isSuccess) return meltResponse;

    // unbinding
    final ( _, _, change ) = meltResponse.data;

    // unblinding
    final unblindingResponse = await EcashManager.shared.unblindingBlindedSignature((
      mint,
      unit,
      change,
      secrets,
      rs,
    ));
    if (!unblindingResponse.isSuccess) {
      return CashuResponse.fromErrorMsg('Unblinding error: ${unblindingResponse.errorMsg}');
    }
    final newProofs = unblindingResponse.data;

    await ProofHelper.deleteProofs(proofs: proofs, mint: mint);

    final amount = newProofs.totalAmount - proofs.totalAmount;
    await HistoryStore.addToHistory(
      amount: amount,
      type: IHistoryType.lnInvoice,
      value: paymentKey,
      mints: [mint.mintURL],
      fee: fee,
    );

    return meltResponse;
  }
}