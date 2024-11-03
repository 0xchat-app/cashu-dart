
import 'dart:convert';

import 'package:cashu_dart/core/nuts/v1/nut_10.dart';
import 'package:flutter/foundation.dart';

import '../../api/nut_P2PK_helper.dart';
import '../../core/DHKE_helper.dart';
import '../../core/keyset_store.dart';
import '../../core/mint_actions.dart';
import '../../core/nuts/define.dart';
import '../../core/nuts/nut_00.dart';
import '../../core/nuts/token/proof.dart';
import '../../core/nuts/v1/nut_02.dart';
import '../../model/cashu_token_info.dart';
import '../../model/keyset_info.dart';
import '../../model/mint_model.dart';
import '../../utils/network/response.dart';
import '../wallet/cashu_manager.dart';
import '../wallet/ecash_manager.dart';
import 'keyset_helper.dart';
import 'proof_store.dart';

class ProofRequest {
  final int amount;
  final List<Proof>? proofs;

  ProofRequest.amount(this.amount)
      : proofs = null;

  ProofRequest.proofs(this.proofs, this.amount);

  @override
  String toString() {
    return '${super.toString()}, amount: $amount, proofs: $proofs';
  }
}

class ProofResponse {
  final bool isSuccess;
  final int targetAmount;
  final int inputFee;
  final List<Proof> proofs;

  int get overAmount => proofs.totalAmount - targetAmount - inputFee;
  bool get isOverProofs => overAmount > 0;

  // Success constructor
  ProofResponse.success({
    required this.targetAmount,
    required this.inputFee,
    required this.proofs,
  }) : isSuccess = true;

  // Failure constructor
  ProofResponse.failure({
    required this.targetAmount,
    this.inputFee = 0,
  })  : isSuccess = false,
        proofs = [];
}

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

  static Future<ProofResponse> _getProofsWithRequest({
    required IMint mint,
    required KeysetInfo keysetInfo,
    required ProofRequest proofRequest,
    bool canIgnoreInputFee = false,
  }) async {
    List<Proof> result = <Proof>[];
    final amount = proofRequest.amount;
    final totalProofs = proofRequest.proofs ?? await getProofs(mint.mintURL, true);

    // Try find available proofs can be combined to match the requested amount without considering input fee
    if (canIgnoreInputFee) {
      result = _findOneSubsetWithSum(totalProofs, amount, 0) ?? [];
      if (result.isNotEmpty) {
        return ProofResponse.success(
          targetAmount: proofRequest.amount,
          inputFee: 0,
          proofs: result,
        );
      }
    }

    // Try find available proofs can be combined to match the requested amount
    result = _findOneSubsetWithSum(totalProofs, amount, keysetInfo.inputFeePPK) ?? [];
    if (result.isNotEmpty) {
      return ProofResponse.success(
        targetAmount: proofRequest.amount,
        inputFee: _getInputFee(result, keysetInfo.inputFeePPK),
        proofs: result,
      );
    }

    int amountAvailable = 0;
    for (final proof in totalProofs) {
      amountAvailable += proof.amountNum;
      result.add(proof);
      if (amountAvailable >= amount) {
        break;
      }
    }

    final inputFee = _getInputFee(result, keysetInfo.inputFeePPK);
    if (amountAvailable >= amount + inputFee) {
      return ProofResponse.success(
        targetAmount: proofRequest.amount,
        inputFee: inputFee,
        proofs: result,
      );
    } else {
      return ProofResponse.failure(
        targetAmount: proofRequest.amount,
      );
    }
  }

  static CashuResponse<List<Proof>> _parseResponseByECashCheck(
    ProofRequest request,
    CashuResponse<List<Proof>> response,
  ) {
    if (!response.isSuccess) return response;
    if (response.data.totalAmount != request.amount) return CashuResponse.fromErrorMsg('Invalid amount proofs.');
    return response;
  }

  static Future<CashuResponse<List<Proof>>> getProofsForECash({
    required IMint mint,
    required ProofRequest proofRequest,
    CashuTokenP2PKInfo? p2pkOption,
    String unit = 'sat',
  }) async {
    // Keyset info
    final keysetInfo = await KeysetHelper.tryGetMintKeysetInfo(mint, unit);
    final keyset = keysetInfo?.keyset ?? {};
    if (keysetInfo == null || keyset.isEmpty) {
      return _parseResponseByECashCheck(
        proofRequest,
        CashuResponse.fromErrorMsg('Keyset not found.'),
      );
    }

    final proofResponse = await _getProofsWithRequest(
      mint: mint,
      keysetInfo: keysetInfo,
      proofRequest: proofRequest,
      canIgnoreInputFee: p2pkOption == null,
    );
    if (!proofResponse.isSuccess) {
      return _parseResponseByECashCheck(
        proofRequest,
        CashuResponse.fromErrorMsg('Insufficient proofs'),
      );
    }
    final proofs = proofResponse.proofs;

    // Can use directly
    if (p2pkOption == null) {
      if (proofResponse.targetAmount == proofResponse.proofs.totalAmount) {
        return _parseResponseByECashCheck(
          proofRequest,
          CashuResponse.fromSuccessData(proofs),
        );
      }
    }
    List<BlindedMessage> blindedMessages = [];
    List<String> secrets = [];
    List<BigInt> rs = [];

    SecretCreator? secretCreator;
    if (p2pkOption != null && p2pkOption.receivePubKeys.isNotEmpty) {
      secretCreator = (_) => NutP2PKHelper.createSecretFromOption(p2pkOption).toSecretString();
    }

    {
      final ( $1, $2, $3, _ ) = DHKEHelper.createBlindedMessages(
        keysetId: keysetInfo.id,
        amount: proofResponse.targetAmount,
        secretCreator: secretCreator,
      );
      blindedMessages.addAll($1);
      secrets.addAll($2);
      rs.addAll($3);
    }
    final targetProofsCount = secrets.length;

    {
      final overAmount = proofResponse.overAmount;
      if (overAmount > 0) {
        final ( $1, $2, $3, _ ) = DHKEHelper.createBlindedMessages(
          keysetId: keysetInfo.id,
          amount: overAmount,
        );
        blindedMessages.addAll($1);
        secrets.addAll($2);
        rs.addAll($3);
      }
    }

    if (blindedMessages.isEmpty) {
      return _parseResponseByECashCheck(
        proofRequest,
        CashuResponse.fromErrorMsg('blindedMessages is empty.'),
      );
    }

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
      [],
      ProofBlindingAction.multiMintSwap,
      '',
    ));
    if (!unblindingResponse.isSuccess) {
      return unblindingResponse;
    }

    await deleteProofs(proofs: proofs, mint: mint);

    return _parseResponseByECashCheck(
      proofRequest,
      CashuResponse.fromSuccessData(
        unblindingResponse.data.sublist(0, targetProofsCount),
      ),
    );
  }

  static Future<CashuResponse<List<Proof>>> getProofsForMelt({
    required IMint mint,
    required ProofRequest proofRequest,
    String unit = 'sat',
  }) async {
    // Keyset info
    final keysetInfo = await KeysetHelper.tryGetMintKeysetInfo(mint, unit);
    final keyset = keysetInfo?.keyset ?? {};
    if (keysetInfo == null || keyset.isEmpty) return CashuResponse.fromErrorMsg('Keyset not found.');

    final proofResponse = await _getProofsWithRequest(
      mint: mint,
      keysetInfo: keysetInfo,
      proofRequest: proofRequest,
    );
    if (!proofResponse.isSuccess) return CashuResponse.fromErrorMsg('Insufficient proofs');

    final proofs = proofResponse.proofs;

    return CashuResponse.fromSuccessData(proofs);
  }

  static Future<CashuResponse<List<List<Proof>>>> getProofsWithAmountList({
    required IMint mint,
    required List<int> amounts,
    CashuTokenP2PKInfo? p2pkOption,
    String unit = 'sat',
  }) async {
    // Keyset info
    final keysetInfo = await KeysetHelper.tryGetMintKeysetInfo(mint, unit);
    final keyset = keysetInfo?.keyset ?? {};
    if (keysetInfo == null || keyset.isEmpty) return CashuResponse.fromErrorMsg('Keyset not found.');

    final totalAmount = amounts.reduce((a, b) => a + b);
    final proofResponse = await _getProofsWithRequest(
      mint: mint,
      keysetInfo: keysetInfo,
      proofRequest: ProofRequest.amount(totalAmount),
    );

    if (!proofResponse.isSuccess) return CashuResponse.fromErrorMsg('Insufficient proofs');

    final proofs = proofResponse.proofs;
    List<List<BlindedMessage>> blindedMessages = [];
    List<List<String>> secrets = [];
    List<List<BigInt>> rs = [];
    List<List<UnblindingOption>> unblindingOptions = [];

    SecretCreator? secretCreator;
    if (p2pkOption != null && p2pkOption.receivePubKeys.isNotEmpty) {
      secretCreator = (_) => NutP2PKHelper.createSecretFromOption(p2pkOption).toSecretString();
    }

    for (var amount in amounts) {
      final ( $1, $2, $3, _ ) = DHKEHelper.createBlindedMessages(
        keysetId: keysetInfo.id,
        amount: amount,
        secretCreator: secretCreator,
      );
      blindedMessages.add($1);
      secrets.add($2);
      rs.add($3);
      unblindingOptions.add(
        List.generate(
          $1.length,
          (index) => p2pkOption != null
            ? const UnblindingOption(isSaveToLocal: false)
            : const UnblindingOption()
        ),
      );
    }

    {
      final overAmount = proofResponse.overAmount;
      if (overAmount > 0) {
        final ( $1, $2, $3, _ ) = DHKEHelper.createBlindedMessages(
          keysetId: keysetInfo.id,
          amount: overAmount,
        );
        blindedMessages.add($1);
        secrets.add($2);
        rs.add($3);
        unblindingOptions.add(
          List.generate($1.length, (index) => const UnblindingOption()),
        );
      }
    }

    List<BlindedMessage> blindedMessagesSet = blindedMessages.expand((e) => e).toList();
    List<String> secretsSet = secrets.expand((e) => e).toList();
    List<BigInt> rsSet = rs.expand((e) => e).toList();
    List<UnblindingOption> unblindingOptionSet = unblindingOptions.expand((e) => e).toList();
    if (blindedMessages.isEmpty) return CashuResponse.fromErrorMsg('blindedMessages is empty.');

    final response = await mint.swapAction(
      mintURL: mint.mintURL,
      proofs: proofs,
      outputs: blindedMessagesSet,
    );
    if (!response.isSuccess) {
      return response.cast();
    }

    // unblinding
    final unblindingResponse = await ProofBlindingManager.shared.unblindingBlindedSignature((
      mint,
      unit,
      response.data,
      secretsSet,
      rsSet,
      unblindingOptionSet,
      ProofBlindingAction.multiMintSwap,
      '',
    ));
    if (!unblindingResponse.isSuccess) {
      return unblindingResponse.cast();
    }

    await deleteProofs(proofs: proofs, mint: mint);

    final newProofs = unblindingResponse.data;
    final proofPackage = <List<Proof>>[];
    int start = 0;
    for (var package in blindedMessages) {
      final packageSize = package.length;
      proofPackage.add(newProofs.sublist(start, start + packageSize));
      start += packageSize;
    }

    return CashuResponse.fromSuccessData(proofPackage);
  }

  static Future<CashuResponse<List<Proof>>> swapProofs({
    required IMint mint,
    required List<Proof> proofs,
    String unit = 'sat',
  }) async {
    // Keyset info
    final keysetInfo = await KeysetHelper.tryGetMintKeysetInfo(mint, unit);
    final keyset = keysetInfo?.keyset ?? {};
    if (keysetInfo == null || keyset.isEmpty) return CashuResponse.fromErrorMsg('Keyset not found.');

    final inputFee = _getInputFee(proofs, keysetInfo.inputFeePPK);
    final outputAmount = proofs.totalAmount - inputFee;
    List<BlindedMessage> blindedMessages = [];
    List<String> secrets = [];
    List<BigInt> rs = [];

    final ( $1, $2, $3, _ ) = DHKEHelper.createBlindedMessages(
      keysetId: keysetInfo.id,
      amount: outputAmount,
    );
    blindedMessages.addAll($1);
    secrets.addAll($2);
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
      [],
      ProofBlindingAction.multiMintSwap,
      '',
    ));
    if (!unblindingResponse.isSuccess) {
      return unblindingResponse;
    }

    await deleteProofs(proofs: proofs, mint: mint);

    return unblindingResponse;
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

  static int _hammingWeight(int n) {
    int count = 0;
    while (n != 0) {
      count += n & 1;
      n >>= 1;
    }
    return count;
  }

  static List<Proof>? _findOneSubsetWithSum(List<Proof> proofs, int target, int inputFeePPK) {
    int adjustedTarget(int subsetLength) {
      return target + ((subsetLength * inputFeePPK + 999) ~/ 1000); // ceil(length * inputFee / 1000)
    }

    // Early exit if the total sum of nums is less than the adjusted target
    if (proofs.totalAmount < adjustedTarget(proofs.length)) {
      return null;
    }

    // Sort nums in descending order to try larger elements first for better efficiency
    proofs.sort((p1, p2) => p1.amountNum.compareTo(p2.amountNum));

    // Use a map to store possible sums and corresponding subsets
    Map<int, List<Proof>?> dp = {0: []};

    for (int i = 0; i < proofs.length; i++) {
      final proof = proofs[i];

      // Create a list of existing keys to avoid modifying the map during iteration
      List<int> keys = dp.keys.toList().reversed.toList();
      for (int t in keys) {
        int newSum = t + proof.amountNum;
        if (newSum <= adjustedTarget(dp[t]!.length + 1)) {
          List<Proof> currentSubset = List.from(dp[t]!)..add(proof);
          int requiredSum = adjustedTarget(currentSubset.length);

          // Early return if the current subset matches the required sum
          if (currentSubset.totalAmount == requiredSum) {
            return currentSubset;
          }

          // Only update dp if it leads to a smaller or new subset for the given sum
          if (!dp.containsKey(newSum) || (dp[newSum]!.length > currentSubset.length)) {
            dp[newSum] = currentSubset;
          }
        }
      }
    }

    return null;
  }

  List<int>? _findOneSubsetWithNums(List<int> nums, int target, int inputFee) {
    int adjustedTarget(int subsetLength) {
      return target + ((subsetLength * inputFee + 999) ~/ 1000); // ceil(length * inputFee / 1000)
    }

    // Early exit if the total sum of nums is less than the adjusted target
    int totalSum = nums.fold(0, (sum, value) => sum + value);
    if (totalSum < adjustedTarget(nums.length)) {
      return null;
    }

    // Sort nums in descending order to try larger elements first for better efficiency
    nums.sort((a, b) => a.compareTo(b));

    // Use a map to store possible sums and corresponding subsets
    Map<int, List<int>?> dp = {0: []};

    for (int i = 0; i < nums.length; i++) {
      int num = nums[i];

      // Create a list of existing keys to avoid modifying the map during iteration
      List<int> keys = dp.keys.toList().reversed.toList();
      for (int t in keys) {
        int newSum = t + num;
        if (newSum <= adjustedTarget(dp[t]!.length + 1)) {
          List<int> currentSubset = List.from(dp[t]!)..add(num);
          int requiredSum = adjustedTarget(currentSubset.length);

          // Early return if the current subset matches the required sum
          if (currentSubset.fold<int>(0, (sum, value) => sum + value) == requiredSum) {
            return currentSubset;
          }

          // Only update dp if it leads to a smaller or new subset for the given sum
          if (!dp.containsKey(newSum) || (dp[newSum]!.length > currentSubset.length)) {
            dp[newSum] = currentSubset;
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

  static Future tryParseProofsToNewestVersion() async {
    final proofs = await ProofStore.getProofs();
    await _tryParseProofsToHexKeysetId(proofs);
  }

  static Future _tryParseProofsToHexKeysetId(List<Proof> proofs) async {
    Map<String, String> keysetIdMap = {};

    List<Proof> oldProofs = [];
    List<Proof> newProofs = [];

    for (var proof in proofs) {
      final originId = proof.id;
      if (Nut2.isHexKeysetId(originId)) continue;

      String? hexKeysetId = keysetIdMap[originId];
      if (hexKeysetId != null && hexKeysetId.isNotEmpty) {
        final newProof = proof.copyWith(id: hexKeysetId);
        if (newProof.id != proof.id || newProof.secret != proof.secret) {
          oldProofs.add(proof);
          newProofs.add(newProof);
        }
        continue;
      }

      final keyset = (await KeysetStore.getKeyset(id: originId)).firstOrNull;
      if (keyset == null) continue;

      hexKeysetId = Nut2.deriveKeySetId(keyset.keyset);
      if (hexKeysetId.isNotEmpty) {
        keysetIdMap[originId] = hexKeysetId;
        final newProof = proof.copyWith(id: hexKeysetId);
        if (newProof.id != proof.id || newProof.secret != proof.secret) {
          oldProofs.add(proof);
          newProofs.add(newProof);
        }
      }
    }

    await ProofStore.addProofs(newProofs);
    await ProofStore.deleteProofs(oldProofs);
  }

  static int _getInputFee(List<Proof> proofs, int inputFeePPK) {
    return (proofs.length * inputFeePPK + 999) ~/ 1000;
  }
}