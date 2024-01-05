
import '../../core/DHKE_helper.dart';
import '../../core/keyset_store.dart';
import '../../core/nuts/DHKE.dart';
import '../../core/nuts/define.dart';
import '../../core/nuts/nut_00.dart';
import '../../model/invoice.dart';
import '../../model/keyset_info.dart';
import '../../model/mint_model.dart';
import '../mint/mint_helper.dart';
import '../proof/proof_helper.dart';
import '../proof/proof_store.dart';
import '../wallet/cashu_manager.dart';
import 'invoice_store.dart';

typedef PayingTheInvoiceResponse = (
  bool paid,
  String preimage,
);

class TransactionHelper {

  /// Obtain the keyset of mint corresponding to the unit.
  /// If the local data is not available, obtain it from the remote endpoint
  static Future<KeysetInfo?> tryGetMintKeysetInfo(IMint mint, String unit, [String? keysetId]) async {
    keysetId ??= mint.keysetId(unit);
    // from local
    final keysets = await KeysetStore.getKeyset(mintURL: mint.mintURL, id: keysetId, unit: unit);
    var keysetInfo = keysets.firstOrNull;

    if (keysetInfo == null || keysetInfo.keyset.isEmpty) {
      // from remote
      final newKeysets = await MintHelper.fetchKeysetFromRemote(mint.mintURL, keysetId);
      keysetInfo = newKeysets.where((element) => element.unit == unit).firstOrNull;
    }
    if (keysetInfo == null) return null;

    // update mint keysetId
    if (keysetInfo.keyset.isNotEmpty) {
      mint.updateKeysetId(keysetInfo.id, unit);
    }

    return keysetInfo;
  }

  static Future<MintKeys?> keysetFetcher(IMint mint, String unit, String keysetId) async {
    final info = await tryGetMintKeysetInfo(mint, unit, keysetId);
    if (info?.keyset.isEmpty ?? true) return null;
    return info?.keyset;
  }

  static Future<Receipt?> requestCreateInvoice({
    required IMint mint,
    required int amount,
    required Future<Receipt?> Function({
      required String mintURL,
      required int amount,
    }) createQuoteAction,
  }) async {
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
    required Future<List<BlindedSignature>?> Function({
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
    final proofs = await DHKE.constructProofs(
      promises: promises,
      rs: rs,
      secrets: secrets,
      keysFetcher: (keysetId) => keysetFetcher(mint, unit, keysetId),
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
    required int fee,
    required Future<MeltResponse?> Function({
      required String mintURL,
      required String quote,
      required List<Proof> inputs,
      required List<BlindedMessage> outputs,
    }) meltAction,
  }) async {

    const failResult = (false, '');

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
    final response = await meltAction(
      mintURL: mint.mintURL,
      quote: quoteID,
      inputs: proofs,
      outputs: blindedMessages,
    );
    if (response == null) return failResult;

    // unbinding
    final ( paid, preimage, change ) = response;
    final newProofs = await DHKE.constructProofs(
      promises: change,
      rs: rs,
      secrets: secrets,
      keysFetcher: (keysetId) => keysetFetcher(mint, unit, keysetId),
    );
    if (newProofs == null) return failResult;

    await ProofStore.addProofs(newProofs);
    ProofHelper.deleteProofs(proofs: proofs, mintURL: mint.mintURL);

    return (
      paid,
      preimage,
    );
  }

  static Future<List<Proof>?> swapProofs({
    required IMint mint,
    required List<Proof> proofs,
    int? supportAmount,
    String unit = 'sat',
    required Future<List<BlindedSignature>?> Function({
      required String mintURL,
      required List<Proof> proofs,
      required List<BlindedMessage> outputs,
    }) swapAction,
  }) async {

    // get keyset
    final keysetInfo = await tryGetMintKeysetInfo(mint, unit);
    final keyset = keysetInfo?.keyset ?? {};
    if (keysetInfo == null || keyset.isEmpty) return null;

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

    final promises = await swapAction(
      mintURL: mint.mintURL,
      proofs: proofs,
      outputs: blindedMessages,
    ) ?? [];

    final newProofs = await DHKE.constructProofs(
      promises: promises,
      rs: rs,
      secrets: secrets,
      keysFetcher: (keysetId) => keysetFetcher(mint, unit, keysetId),
    );
    if (newProofs == null) return null;

    await ProofStore.addProofs(newProofs);
    ProofHelper.deleteProofs(proofs: proofs, mintURL: mint.mintURL);
    return newProofs;
  }
}