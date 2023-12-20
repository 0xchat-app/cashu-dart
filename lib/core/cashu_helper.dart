
import 'dart:math';
import 'dart:typed_data';

import 'package:cashu_dart/core/nuts/nut_00.dart';
import 'package:cashu_dart/core/nuts/nut_05.dart';
import 'package:cashu_dart/core/nuts/nut_06.dart';
import 'package:cashu_dart/core/nuts/nut_08.dart';

import '../utils/tools.dart';
import 'nuts/DHKE.dart';
import 'nuts/define.dart';
import 'nuts/nut_01.dart';
import 'nuts/nut_04.dart';

typedef PayingTheInvoiceResponse = (
  bool paid,
  String preimage,
  List<Proof> newProof,
);

class CashuHelper {

  static Future<List<Proof>?> requestTokensFromMint({
    required String mintURL,
    required int amount,
    required String hash,
    MintKeys? keys,
  }) async {
    final ( blindedMessages, secrets, rs, _ ) =
      CashuHelperPrivateEx._createBlindedMessages(amount: amount);

    keys ??= await Nut1.getKeys(mintURL: mintURL);
    if (keys == null) return null;

    final promises = await Nut4.requestTokensFromMint(
      mintURL: mintURL,
      blindedMessages: blindedMessages,
      hash: hash,
    );
    if (promises == null) return null;

    final proofs = DHKE.constructProofs(
      promises: promises,
      rs: rs,
      secrets: secrets,
      keys: keys,
    );

    return proofs;
  }

  static Future<PayingTheInvoiceResponse> payingTheInvoice({
    required String mintURL,
    required String pr,
    required List<Proof> proofs,
    int? feeReserve,
    MintKeys? keys,
  }) async {

    final failResult = (false, '', <Proof>[]);

    keys ??= await Nut1.getKeys(mintURL: mintURL);
    if (keys == null) return failResult;

    feeReserve ??= await Nut5.checkingLightningFees(
      mintURL: mintURL,
      pr: pr,
    );

    if (feeReserve == null) return failResult;

    final ( blindedMessages, secrets, rs, _ ) =
      CashuHelperPrivateEx._createBlankOutputs(feeReserve);

    final response = await Nut8.payingTheInvoice(
      mintURL: mintURL,
      pr: pr,
      proofs: proofs,
      outputs: blindedMessages,
    );
    if (response == null) return failResult;

    final ( paid, preimage, change ) = response;
    final newProofs = DHKE.constructProofs(
      promises: change,
      rs: rs,
      secrets: secrets,
      keys: keys,
    ) ?? [];

    return (
      paid,
      preimage,
      newProofs
    );
  }

  static Future<List<Proof>> splitProofs({
    required String mintURL,
    required List<Proof> proofs,
    int? supportAmount,
    MintKeys? keys,
  }) async {

    keys ??= await Nut1.getKeys(mintURL: mintURL);
    if (keys == null) return [];

    final proofsTotalAmount = proofs.fold<BigInt>(BigInt.zero, (pre, proof) {
      final amount = BigInt.tryParse(proof.amount) ?? BigInt.zero;
      return pre + amount;
    });

    final amount = supportAmount ?? proofsTotalAmount.toInt();
    List<BlindedMessage> blindedMessages = [];
    List<Uint8List> secrets = [];
    List<BigInt> rs = [];
    {
      final ( $1, $2, $3, _ ) = CashuHelperPrivateEx._createBlindedMessages(
        amount: amount,
      );
      blindedMessages.addAll($1);
      secrets.addAll($2);
      rs.addAll($3);
    }
    {
      final ( $1, $2, $3, _ ) = CashuHelperPrivateEx._createBlindedMessages(
        amount: proofsTotalAmount.toInt() - amount,
      );
      blindedMessages.addAll($1);
      secrets.addAll($2);
      rs.addAll($3);
    }

    final promises = await Nut6.split(
      mintURL: mintURL,
      proofs: proofs,
      outputs: blindedMessages,
    ) ?? [];

    final newProofs = DHKE.constructProofs(
      promises: promises,
      rs: rs,
      secrets: secrets,
      keys: keys,
    ) ?? [];

    return newProofs;
  }

}

extension CashuHelperPrivateEx on CashuHelper {

  static BlindedMessageData _createRandomBlindedMessages({
    required List<int> amounts,
  }) {
    List<BlindedMessage> blindedMessages = [];
    List<Uint8List> secrets = [];
    List<BigInt> rs = [];

    for (final amount in amounts) {
      final secret = DHKE.randomPrivateKey();
      final (B_, r) = DHKE.blindMessage(secret);
      if (B_.isEmpty) continue;

      final blindedMessage = BlindedMessage(
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
    required int amount,
  }) {
    List<int> amounts = splitAmount(amount);
    return _createRandomBlindedMessages(amounts: amounts);
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

  static BlindedMessageData _createBlankOutputs(int feeReserve) {
    var count = 1;
    if (feeReserve != 0) {
      count = max(1, (log(feeReserve) / ln2).ceil());
    }
    final amounts = List.generate(count, (index) => 0);
    return _createRandomBlindedMessages(amounts: amounts);
  }
}