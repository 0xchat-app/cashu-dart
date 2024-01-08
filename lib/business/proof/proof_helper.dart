
import 'package:cashu_dart/cashu_dart.dart';
import 'package:cashu_dart/utils/tools.dart';

import '../../api/cashu_api.dart';
import '../../core/DHKE_helper.dart';
import '../../core/keyset_store.dart';
import '../../core/nuts/DHKE.dart';
import '../../core/nuts/define.dart';
import '../../core/nuts/nut_00.dart';
import '../../core/nuts/v0/nut.dart' as v0;
import '../../core/nuts/v1/nut.dart' as v1;
import '../../utils/network/response.dart';
import '../transaction/transaction_helper.dart';
import '../wallet/cashu_manager.dart';
import 'keyset_helper.dart';
import 'proof_store.dart';

typedef TokenCheckAction = Future<CashuResponse<List<TokenState>>> Function({
  required String mintURL,
  required List<Proof> proofs,
});

class ProofHelper {

  static TokenCheckAction get checkAction => Cashu.isV1
      ? v1.Nut7.requestTokenState
      : v0.Nut7.requestTokenState;

  static Future<List<Proof>> getProofs(
    String mintURL,
    [bool orderAsc = false]
  ) async {
    final keysets = await KeysetStore.getKeyset(mintURL: mintURL);
    final usableProofs = await ProofStore.getProofs(ids: keysets.map((e) => e.id).toList());
    if (orderAsc) {
      usableProofs.sort((a, b) => a.amount.compareTo(b.amount));
    } else {
      usableProofs.sort((a, b) => b.amount.compareTo(a.amount));
    }
    return usableProofs;
  }

  static Future<List<Proof>> getProofsToUse({
    required String mintURL,
    required BigInt amount,
    bool orderAsc = false,
    List<Proof>? proofs,
    bool checkState = true,
    bool isFromSwap = false,
  }) async {
    proofs ??= await getProofs(mintURL, orderAsc);
    // check state
    if (checkState) {
      final response = await checkAction(mintURL: mintURL, proofs: proofs);
      if (!response.isSuccess) return [];
      if (response.data.length != proofs.length) {
        throw Exception('[E][Cashu - checkProofsAvailable] '
            'The length of states(${response.data.length}) and proofs(${proofs.length}) is not consistent');
      }

      // get usable proofs
      final usableProofs = <Proof>[];
      for (int i = 0; i < proofs.length; i++) {
        if (response.data[i] == TokenState.live) {
          usableProofs.add(proofs[i]);
        }
      }

      proofs = usableProofs;
    }

    final List<Proof> proofsToSend = [];
    final List<Proof> proofsToKeep = [...proofs];
    BigInt amountAvailable = BigInt.zero;

    for (final proof in proofs) {
      if (amountAvailable >= amount) break;
      amountAvailable += proof.amount.asBigInt();
      proofsToSend.add(proof);
      proofsToKeep.remove(proof);
    }

    final totalAmount = proofs.totalAmount;
    if (BigInt.from(totalAmount) == amount) {
      return proofs;
    }

    if (isFromSwap) return [];

    final mint = await CashuManager.shared.getMint(mintURL);
    if (mint == null) return [];
    final newProofs = await swapProofs(
      mint: mint,
      proofs: proofs,
      supportAmount: amount.toInt(),
      swapAction: Cashu.isV1 ? v1.Nut3.swap : v0.Nut6.split,
    );

    final finalProofs = await ProofHelper.getProofsToUse(
      mintURL: mint.mintURL,
      amount: amount,
      proofs: newProofs,
      checkState: false,
      isFromSwap: true,
    );
    return finalProofs;
  }

  static deleteProofs({
    required List<Proof> proofs,
    required String? mintURL,
  }) async {
    final burnedProofs = <Proof>[];
    if (mintURL != null && mintURL.isNotEmpty) {
      final response = await checkAction(mintURL: mintURL, proofs: proofs);
      if (!response.isSuccess) return null;
      if (response.data.length != proofs.length) {
        throw Exception('[E][Cashu - checkProofsAvailable] '
            'The length of states(${response.data.length}) and proofs(${proofs.length}) is not consistent');
      }
      for (int i = 0; i < proofs.length; i++) {
        if (response.data[i] == TokenState.burned) {
          burnedProofs.add(proofs[i]);
        }
      }
    } else {
      burnedProofs.addAll(proofs);
    }

    await ProofStore.deleteProofs(burnedProofs);
  }

  static Future<List<Proof>?> swapProofs({
    required IMint mint,
    required List<Proof> proofs,
    int? supportAmount,
    String unit = 'sat',
    required Future<CashuResponse<List<BlindedSignature>>> Function({
    required String mintURL,
    required List<Proof> proofs,
    required List<BlindedMessage> outputs,
    }) swapAction,
  }) async {

    // get keyset
    final keysetInfo = await KeysetHelper.tryGetMintKeysetInfo(mint, unit);
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

    final response = await swapAction(
      mintURL: mint.mintURL,
      proofs: proofs,
      outputs: blindedMessages,
    );
    if (!response.isSuccess) return null;

    final newProofs = await DHKE.constructProofs(
      promises: response.data,
      rs: rs,
      secrets: secrets,
      keysFetcher: (keysetId) => KeysetHelper.keysetFetcher(mint, unit, keysetId),
    );
    if (newProofs == null) return null;

    await ProofStore.addProofs(newProofs);
    ProofHelper.deleteProofs(proofs: proofs, mintURL: mint.mintURL);
    return newProofs;
  }
}