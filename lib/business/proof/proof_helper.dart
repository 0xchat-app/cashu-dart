
import 'dart:convert';

import 'package:cashu_dart/core/nuts/v1/nut_10.dart';
import 'package:flutter/foundation.dart';

import '../../business/wallet/ecash_manager.dart';
import '../../core/DHKE_helper.dart';
import '../../core/keyset_store.dart';
import '../../core/mint_actions.dart';
import '../../core/nuts/DHKE.dart';
import '../../core/nuts/define.dart';
import '../../core/nuts/nut_00.dart';
import '../../core/nuts/v1/nut_11.dart';
import '../../model/mint_model.dart';
import '../../utils/network/response.dart';
import '../../utils/tools.dart';
import '../wallet/cashu_manager.dart';
import 'keyset_helper.dart';
import 'proof_store.dart';

class ProofHelper {

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

  static Future<CashuResponse<List<Proof>>> getProofsToUse({
    required IMint mint,
    BigInt? amount,
    List<Proof>? proofs,
    bool orderAsc = false,
    bool checkState = false,
    bool isFromSwap = false,
  }) async {
    proofs ??= await getProofs(mint.mintURL, orderAsc);
    // check state
    if (checkState) {
      final response = await mint.tokenCheckAction(mintURL: mint.mintURL, proofs: proofs);
      if (!response.isSuccess) return response.cast();
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
    BigInt amountAvailable = BigInt.zero;

    if (amount != null && BigInt.from(proofs.totalAmount) < amount) {
      return CashuResponse.fromErrorMsg('Insufficient proofs');
    }

    // Try use
    if (amount != null) {
      final proofIndex = _findOneSubsetWithSum(proofs.map((p) => p.amountNum).toList(), amount.toInt());
      if (proofIndex != null && proofIndex.isNotEmpty) {
        try {
          final responseProofs = proofIndex.map((index) {
            final proof = proofs![index];
            addSignatureToProof(proof: proof);
            return proof;
          }).toList();
          return CashuResponse.fromSuccessData(responseProofs);
        } catch (_) { }
      }
    }

    for (final proof in proofs) {
      if (amount != null && amountAvailable >= amount) break;
      amountAvailable += proof.amount.asBigInt();
      addSignatureToProof(proof: proof);
      proofsToSend.add(proof);
    }

    final totalAmount = proofsToSend.totalAmount;
    if (proofsToSend.length <= _hammingWeight(totalAmount)) {
      if (amount == null || BigInt.from(totalAmount) == amount) {
        return CashuResponse.fromSuccessData(proofsToSend);
      }
    }

    // Prevent infinite recursion
    if (isFromSwap) return CashuResponse.fromErrorMsg('Local error');

    final response = await swapProofs(
      mint: mint,
      proofs: proofsToSend,
      supportAmount: amount != null ? amount.toInt() : proofsToSend.totalAmount,
    );
    if (!response.isSuccess) return response;

    final newProofs = response.data;
    final finalProofs = await getProofsToUse(
      mint: mint,
      amount: amount,
      proofs: newProofs,
      checkState: false,
      isFromSwap: true,
    );
    return finalProofs;
  }

  static Future<bool> deleteProofs({
    required List<Proof> proofs,
    IMint? mint,
  }) async {
    final burnedProofs = <Proof>[];
    if (mint != null) {
      final response = await mint.tokenCheckAction(mintURL: mint.mintURL, proofs: proofs);
      if (!response.isSuccess) return false;
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

    return await ProofStore.deleteProofs(burnedProofs);
  }

  static Future<CashuResponse<List<Proof>>> swapProofs({
    required IMint mint,
    required List<Proof> proofs,
    int? supportAmount,
    String unit = 'sat',
    bool syncDelete = true,
  }) async {
    // get keyset
    final keysetInfo = await KeysetHelper.tryGetMintKeysetInfo(mint, unit);
    final keyset = keysetInfo?.keyset ?? {};
    if (keysetInfo == null || keyset.isEmpty) return CashuResponse.fromErrorMsg('Keyset not found.');

    final proofsTotalAmount = proofs.totalAmount;

    final amount = supportAmount ?? proofsTotalAmount;
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
      if (proofsTotalAmount - amount > 0) {
        final ( $1, $2, $3, _ ) = DHKEHelper.createBlindedMessages(
          keysetId: keysetInfo.id,
          amount: proofsTotalAmount - amount,
        );
        blindedMessages.addAll($1);
        secrets.addAll($2);
        rs.addAll($3);
      }
    }

    if (blindedMessages.isEmpty) return CashuResponse.fromErrorMsg('blindedMessages is empty.');

    final response = await mint.swapAction(
      mintURL: mint.mintURL,
      proofs: proofs,
      outputs: blindedMessages,
    );
    if (!response.isSuccess) {
      return response.cast();
    }

    // unblinding
    final unblindingResponse = await ProofBlindingManager.shared.unblindingBlindedSignature((
      mint,
      unit,
      response.data,
      secrets,
      rs,
      ProofBlindingAction.multiMintSwap,
      '',
    ));
    if (!unblindingResponse.isSuccess) {
      return unblindingResponse;
    }

    if (syncDelete) {
      await deleteProofs(proofs: proofs, mint: mint);
    } else {
      deleteProofs(proofs: proofs, mint: mint);
    }
    return unblindingResponse;
  }

  static Future<CashuResponse<List<Proof>>> swapProofsForP2PK({
    required IMint mint,
    required List<Proof> proofs,
    required List<String> publicKeys,
    List<String>? refundPubKeys,
    int? locktime,
    int? signNumRequired,
    P2PKSecretSigFlag? sigFlag,
    String unit = 'sat',
  }) async {

    final p2pkSecretData = publicKeys.removeAt(0);
    final p2pkSecretTags = [
      if (publicKeys.isNotEmpty) P2PKSecretTagKey.pubkeys.appendValues(publicKeys),
      if (refundPubKeys != null && refundPubKeys.isNotEmpty) P2PKSecretTagKey.refund.appendValues(refundPubKeys),
      if (signNumRequired != null && signNumRequired > 0) P2PKSecretTagKey.nSigs.appendValues(['$signNumRequired']),
      if (locktime != null) P2PKSecretTagKey.lockTime.appendValues([locktime.toString()]),
      if (sigFlag != null) P2PKSecretTagKey.sigflag.appendValues([sigFlag.value]),
    ];
    final secrets = proofs.map((_) =>
        P2PKSecret(
          nonce: DHKE.randomPrivateKey().asBase64String(),
          data: p2pkSecretData,
          tags: p2pkSecretTags,
        ).toSecretString(),
    ).toList();

    // get keyset
    final keysetInfo = await KeysetHelper.tryGetMintKeysetInfo(mint, unit);
    final keyset = keysetInfo?.keyset ?? {};
    if (keysetInfo == null || keyset.isEmpty) return CashuResponse.fromErrorMsg('Keyset not found.');

    List<BlindedMessage> blindedMessages = [];
    List<String> pSecrets = [];
    List<BigInt> rs = [];

    final ( $1, $2, $3, _ ) = DHKEHelper.createBlindedMessagesWithSecret(
      keysetId: keysetInfo.id,
      amounts: proofs.map((p) => int.parse(p.amount)).toList(),
      secrets: secrets,
    );
    blindedMessages.addAll($1);
    pSecrets.addAll($2);
    rs.addAll($3);

    if (blindedMessages.isEmpty) return CashuResponse.fromErrorMsg('blindedMessages is empty.');

    final response = await mint.swapAction(
      mintURL: mint.mintURL,
      proofs: proofs,
      outputs: blindedMessages,
    );
    if (!response.isSuccess) {
      return response.cast();
    }

    // unblinding
    final unblindingResponse = await ProofBlindingManager.shared.unblindingBlindedSignature((
      mint,
      unit,
      response.data,
      secrets,
      rs,
      ProofBlindingAction.swapForP2PK,
      '',
    ));
    if (!unblindingResponse.isSuccess) {
      return unblindingResponse;
    }

    await deleteProofs(proofs: proofs, mint: mint);
    return unblindingResponse;
  }

  static int _hammingWeight(int n) {
    int count = 0;
    while (n != 0) {
      count += n & 1;
      n >>= 1;
    }
    return count;
  }

  static List<int>? _findOneSubsetWithSum(List<int> nums, int target) {
    List<List<int>?> dp = List.filled(target + 1, null);
    dp[0] = [];

    for (int i = 0; i < nums.length; i++) {
      int num = nums[i];

      for (int t = target; t >= num; t--) {
        if (dp[t - num] != null) {
          dp[t] = List.from(dp[t - num]!)..add(i);

          if (t == target) {
            return dp[target];
          }
        }
      }
    }

    return null;
  }

  static Future addSignatureToProof({
    required Proof proof,
    List<String> pubkeyList = const [],
  }) async {

    final nut10Data = Nut10.dataFromSecretString(proof.secret);
    if (nut10Data == null) return ;

    final (kind, _, _, _) = nut10Data;
    if (kind != ConditionType.p2pk) return ;

    final defaultKey = CashuManager.shared.defaultSignPubkey?.call() ?? '';
    final immutablePubkeyList = [
      ...pubkeyList,
      if (defaultKey.isNotEmpty && !pubkeyList.contains(defaultKey))
        defaultKey
    ];
    try {
      final witnessRaw = proof.witness;
      Map witness = {};
      if (witnessRaw.isNotEmpty) {
        witness = jsonDecode(witnessRaw) as Map;
      }
      var originSign = witness['signatures'];
      if (originSign is! List) {
        originSign = [];
      }
      final signatures = [...originSign.map((e) => e.toString()).toList().cast<String>()];
      for (var pubkey in immutablePubkeyList) {
        final sign = await CashuManager.shared.signFn?.call(pubkey, proof.secret);
        if (sign != null && sign.isNotEmpty) signatures.add(sign);
      }

      if (signatures.isNotEmpty) {
        witness['signatures'] = signatures;
      }

      if (witness.isNotEmpty) {
        proof.witness = jsonEncode(witness);
      }
    } catch (e, stack) {
      debugPrint('[E][Cashu - addSignatureToProof] $e');
      debugPrint('[E][Cashu - addSignatureToProof] $stack');
    }
  }
}