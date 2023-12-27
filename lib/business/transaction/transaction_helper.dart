
import 'package:cashu_dart/business/proof/proof_helper.dart';

import '../../core/DHKE_helper.dart';
import '../../core/keyset_store.dart';
import '../../core/nuts/DHKE.dart';
import '../../core/nuts/nut_00.dart';
import '../../core/nuts/nut_03.dart';
import '../../core/nuts/nut_04.dart';
import '../../core/nuts/nut_05.dart';
import '../../core/nuts/nut_08.dart';
import '../../model/keyset_info.dart';
import '../../model/mint_model.dart';
import '../mint/mint_helper.dart';
import '../proof/proof_store.dart';

typedef PayingTheInvoiceResponse = (
  bool paid,
  String preimage,
  List<Proof> newProof,
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

  static Future<List<Proof>?> requestTokensFromMint({
    required IMint mint,
    required String quoteID,
    required int amount,
    String unit = 'sat'
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
    final promises = await Nut4.requestTokensFromMint(
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

    return proofs;
  }

  static Future<PayingTheInvoiceResponse> payingTheQuote({
    required IMint mint,
    required String quoteID,
    required List<Proof> proofs,
    String unit = 'sat',
    int? fee,
  }) async {

    final failResult = (false, '', <Proof>[]);

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

    return (
    paid,
    preimage,
    newProofs
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
    ProofHelper.tryDeleteProofs(mint.mintURL, proofs);
    return newProofs;
  }
}