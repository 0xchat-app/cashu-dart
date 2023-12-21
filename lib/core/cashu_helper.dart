
import 'dart:math';

import 'package:cashu_dart/core/keyset_store.dart';
import 'package:cashu_dart/core/nuts/nut_08.dart';

import '../model/mint_model.dart';
import '../utils/tools.dart';
import 'nuts/DHKE.dart';
import 'nuts/define.dart';
import 'nuts/nut_00.dart';
import 'nuts/nut_01.dart';
import 'nuts/nut_02.dart';
import 'nuts/nut_03.dart';
import 'nuts/nut_04.dart';
import 'nuts/nut_05.dart';

typedef PayingTheInvoiceResponse = (
  bool paid,
  String preimage,
  List<Proof> newProof,
);

class CashuHelper {

  static Future<List<Proof>?> requestTokensFromMint({
    required IMint mint,
    required int amount,
    required String quoteID,
  }) async {

    // check quote state
    // final quoteInfo = await Nut4.checkMintQuoteState(
    //   mintURL: mint.mintURL,
    //   quoteID: quoteID,
    // );
    // if (quoteInfo == null) return null;
    // if (quoteInfo.expiry < 1 || quoteInfo.paid) return null;

    // get keyset from local
    final keysets = await KeysetStore.getKeyset(mintURL: mint.mintURL);
    final keysetInfo = keysets.where((element) => element.active).firstOrNull;
    if (keysetInfo == null) {
      KeysetStore.fetchFromMint(mint.mintURL);
      await Nut1.requestKeys(mintURL: mint.mintURL);
      return null;
    }

    final keyset = keysetInfo.keyset;
    if (keyset.isEmpty) {
      final result = (await Nut1.requestKeys(mintURL: mint.mintURL, keysetId: keysetInfo.id))?.firstOrNull;
      if (result != null) {
        keyset.addAll(result.keys);
        KeysetStore.addOrReplaceKeysets([keysetInfo]);
      } else {
        return null;
      }
    }

    final ( blindedMessages, secrets, rs, _ ) =
    CashuHelperPrivateEx._createBlindedMessages(
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

    final proofs = DHKE.constructProofs(
      promises: promises,
      rs: rs,
      secrets: secrets,
      keys: keyset,
    );

    return proofs;
  }
  //
  // static Future<PayingTheInvoiceResponse> meltToken({
  //   required String mintURL,
  //   required String quoteID,
  //   required List<Proof> proofs,
  //   MintKeys? keys,
  // }) async {
  //
  //   final failResult = (false, '', <Proof>[]);
  //
  //   // check quote state
  //   final quoteInfo = await Nut5.checkMintQuoteState(
  //     mintURL: mintURL,
  //     quoteID: quoteID,
  //   );
  //   if (quoteInfo == null) return failResult;
  //   if (quoteInfo.expiry < 1 || quoteInfo.paid) return failResult;
  //
  //   final fee = int.parse(quoteInfo.fee);
  //
  //   keys ??= await Nut1.requestKeys(mintURL: mintURL);
  //   if (keys == null) return failResult;
  //   final keysetId = Nut2.deriveKeySetId(keys);
  //
  //   final ( blindedMessages, secrets, rs, _ ) =
  //     CashuHelperPrivateEx._createBlankOutputs(
  //       keysetId: keysetId,
  //       amount: fee,
  //     );
  //
  //   final response = await Nut8.payingTheInvoice(
  //     mintURL: mintURL,
  //     quote: quoteID,
  //     inputs: proofs,
  //     outputs: blindedMessages,
  //   );
  //   if (response == null) return failResult;
  //
  //   final ( paid, preimage, change ) = response;
  //   final newProofs = DHKE.constructProofs(
  //     promises: change,
  //     rs: rs,
  //     secrets: secrets,
  //     keys: keys,
  //   ) ?? [];
  //
  //   return (
  //     paid,
  //     preimage,
  //     newProofs
  //   );
  // }
  //
  // static Future<List<Proof>> swapProofs({
  //   required String mintURL,
  //   required List<Proof> proofs,
  //   int? supportAmount,
  //   MintKeys? keys,
  // }) async {
  //
  //   keys ??= await Nut1.requestKeys(mintURL: mintURL);
  //   if (keys == null) return [];
  //   final keysetId = Nut2.deriveKeySetId(keys);
  //
  //   final proofsTotalAmount = proofs.fold<BigInt>(BigInt.zero, (pre, proof) {
  //     final amount = BigInt.tryParse(proof.amount) ?? BigInt.zero;
  //     return pre + amount;
  //   });
  //
  //   final amount = supportAmount ?? proofsTotalAmount.toInt();
  //   List<BlindedMessage> blindedMessages = [];
  //   List<String> secrets = [];
  //   List<BigInt> rs = [];
  //   {
  //     final ( $1, $2, $3, _ ) = CashuHelperPrivateEx._createBlindedMessages(
  //       keysetId: keysetId,
  //       amount: amount,
  //     );
  //     blindedMessages.addAll($1);
  //     secrets.addAll($2);
  //     rs.addAll($3);
  //   }
  //   {
  //     final ( $1, $2, $3, _ ) = CashuHelperPrivateEx._createBlindedMessages(
  //       keysetId: keysetId,
  //       amount: proofsTotalAmount.toInt() - amount,
  //     );
  //     blindedMessages.addAll($1);
  //     secrets.addAll($2);
  //     rs.addAll($3);
  //   }
  //
  //   final promises = await Nut3.swap(
  //     mintURL: mintURL,
  //     proofs: proofs,
  //     outputs: blindedMessages,
  //   ) ?? [];
  //
  //   final newProofs = DHKE.constructProofs(
  //     promises: promises,
  //     rs: rs,
  //     secrets: secrets,
  //     keys: keys,
  //   ) ?? [];
  //
  //   return newProofs;
  // }

}

extension CashuHelperPrivateEx on CashuHelper {

  static BlindedMessageData _createRandomBlindedMessages({
    required String keysetId,
    required List<int> amounts,
  }) {
    List<BlindedMessage> blindedMessages = [];
    List<String> secrets = [];
    List<BigInt> rs = [];

    for (final amount in amounts) {
      final secret = DHKE.randomPrivateKey().asBase64String();
      final (B_, r) = DHKE.blindMessage(secret.asBytes());
      if (B_.isEmpty) continue;

      final blindedMessage = BlindedMessage(
        id: keysetId,
        amount: amount,
        B_: B_,
      );
      blindedMessages.add(blindedMessage);
      secrets.add(secret);
      rs.add(r);
    }

    return (
      blindedMessages,
      secrets,
      rs,
      amounts,
    );
  }

  static BlindedMessageData _createBlindedMessages({
    required String keysetId,
    required int amount,
  }) {
    List<int> amounts = splitAmount(amount);
    return _createRandomBlindedMessages(
      keysetId: keysetId,
      amounts: amounts,
    );
  }

  static List<int> splitAmount(int value) {
    if (value == 0) return [];
    List<int> chunks = [];
    for (int i = 0; i < 32; i++) {
      int mask = 1 << i;
      if ((value & mask) != 0) {
        chunks.add(pow(2, i).toInt());
      }
    }
    return chunks;
  }

  static BlindedMessageData _createBlankOutputs({
    required String keysetId,
    required int amount,
  }) {
    var count = 1;
    if (amount != 0) {
      count = max(1, (log(amount) / ln2).ceil());
    }
    final amounts = List.generate(count, (index) => 0);
    return _createRandomBlindedMessages(
      keysetId: keysetId,
      amounts: amounts,
    );
  }
}