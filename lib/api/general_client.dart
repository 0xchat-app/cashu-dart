
import 'dart:convert';

import 'package:bolt11_decoder/bolt11_decoder.dart';
import 'package:flutter/foundation.dart';

import '../business/proof/proof_helper.dart';
import '../business/proof/proof_store.dart';
import '../business/proof/token_helper.dart';
import '../business/transaction/hitstory_store.dart';
import '../business/wallet/cashu_manager.dart';
import '../core/nuts/nut_00.dart';
import '../core/nuts/v1/nut_11.dart';
import '../model/cashu_token_info.dart';
import '../model/history_entry.dart';
import '../model/lightning_invoice.dart';
import '../model/mint_model.dart';
import '../utils/network/response.dart';
import 'nut_P2PK_helper.dart';

typedef SignWithKeyFunction = Future<String> Function(String key, String message);

class CashuAPIGeneralClient {

  static const _lnPrefix = [
    'lightning:',
    'lightning=',
    'lightning://',
    'lnurlp://',
    'lnurlp=',
    'lnurlp:',
    'lnurl:',
    'lnurl=',
    'lnurl://',
  ];

  static Future<CashuResponse<String>> sendEcash({
    required IMint mint,
    required int amount,
    String memo = '',
    String unit = 'sat',
    List<Proof>? proofs,
  }) async {

    await CashuManager.shared.setupFinish.future;

    // get proofs
    if (proofs == null) {
      final response = await ProofHelper.getProofsToUse(
        mint: mint,
        amount: BigInt.from(amount),
      );
      if (!response.isSuccess) return response.cast();

      proofs = response.data;
    }

    if (proofs.totalAmount != amount) {
      final response = await ProofHelper.getProofsToUse(
        mint: mint,
        amount: BigInt.from(amount),
        proofs: proofs,
      );
      if (!response.isSuccess) return response.cast();

      proofs = response.data;
    }

    final encodedToken = TokenHelper.getEncodedToken(
      Token(
        token: [TokenEntry(mint: mint.mintURL, proofs: proofs)],
        memo: memo,
        unit: unit,
      ),
    );

    await HistoryStore.addToHistory(
      amount: -amount,
      type: IHistoryType.eCash,
      value: encodedToken,
      mints: [mint.mintURL],
    );

    await ProofHelper.deleteProofs(proofs: proofs);
    await CashuManager.shared.updateMintBalance(mint);

    debugPrint('[I][Cashu - sendEcash] Create Ecash: $encodedToken');
    return CashuResponse.fromSuccessData(encodedToken);
  }

  static Future<CashuResponse<List<String>>> sendEcashList({
    required IMint mint,
    required List<int> amountList,
    List<String> publicKeys = const [],
    List<String>? refundPubKeys,
    int? locktime,
    int? signNumRequired,
    String memo = '',
    String unit = 'sat',
  }) async {

    await CashuManager.shared.setupFinish.future;

    final deletedProofs = <Proof>[];
    final tokenList = <String>[];
    final deletedHistoryIds = <String>[];

    for (var i = 0; i < amountList.length; i++) {
      final amount = amountList[i];

      // get proofs
      final response = await ProofHelper.getProofsToUse(
        mint: mint,
        amount: BigInt.from(amount),
        checkState: i == 0,
      );
      if (!response.isSuccess) {
        // add the deleted proof
        await ProofStore.addProofs(deletedProofs);
        await HistoryStore.deleteHistory(deletedHistoryIds);
        return response.cast();
      }

      var proofs = response.data;
      if (publicKeys.isNotEmpty) {
        final swapResponse = await ProofHelper.swapProofsForP2PK(
          mint: mint,
          proofs: proofs,
          publicKeys: [...publicKeys],
          refundPubKeys: refundPubKeys,
          locktime: locktime,
          signNumRequired: signNumRequired,
        );
        if (!swapResponse.isSuccess) {
          // add the deleted proof
          await ProofStore.addProofs(deletedProofs);
          await HistoryStore.deleteHistory(deletedHistoryIds);
          return response.cast();
        }
        proofs = swapResponse.data;
      }

      final encodedToken = TokenHelper.getEncodedToken(
        Token(
          token: [TokenEntry(mint: mint.mintURL, proofs: proofs)],
          memo: memo,
          unit: unit,
        ),
      );

      tokenList.add(encodedToken);
      deletedProofs.addAll(proofs);
      final history = await HistoryStore.addToHistory(
        amount: -amount,
        type: IHistoryType.eCash,
        value: encodedToken,
        mints: [mint.mintURL],
      );
      deletedHistoryIds.add(history.id);
      await ProofHelper.deleteProofs(proofs: proofs);
    }

    await CashuManager.shared.updateMintBalance(mint);

    return CashuResponse.fromSuccessData(tokenList);
  }

  static Future<CashuResponse<String>> sendEcashToPublicKeys({
    required IMint mint,
    required int amount,
    required List<String> publicKeys,
    List<String>? refundPubKeys,
    int? locktime,
    int? signNumRequired,
    P2PKSecretSigFlag? sigFlag,
    String memo = '',
    String unit = 'sat',
    List<Proof>? proofs,
  }) async {

    await CashuManager.shared.setupFinish.future;

    if (publicKeys.isEmpty) {
      return CashuResponse.fromErrorMsg('PublicKeys is empty.');
    }

    // get proofs
    if (proofs == null) {
      final response = await ProofHelper.getProofsToUse(
        mint: mint,
        amount: BigInt.from(amount),
      );
      if (!response.isSuccess) return response.cast();

      proofs = response.data;
    }

    if (proofs.totalAmount != amount) {
      final response = await ProofHelper.getProofsToUse(
        mint: mint,
        amount: BigInt.from(amount),
        proofs: proofs,
      );
      if (!response.isSuccess) return response.cast();

      proofs = response.data;
    }

    final swapResponse = await ProofHelper.swapProofsForP2PK(
      mint: mint,
      proofs: proofs,
      publicKeys: publicKeys,
      refundPubKeys: refundPubKeys,
      locktime: locktime,
      signNumRequired: signNumRequired,
      sigFlag: sigFlag,
    );
    if (!swapResponse.isSuccess) return swapResponse.cast();

    final p2pkProofs = swapResponse.data;
    final encodedToken = TokenHelper.getEncodedToken(
      Token(
        token: [TokenEntry(mint: mint.mintURL, proofs: p2pkProofs)],
        memo: memo,
        unit: unit,
      ),
    );

    await HistoryStore.addToHistory(
      amount: -amount,
      type: IHistoryType.eCash,
      value: encodedToken,
      mints: [mint.mintURL],
    );

    await ProofHelper.deleteProofs(proofs: p2pkProofs);
    await CashuManager.shared.updateMintBalance(mint);

    debugPrint('[I][Cashu - sendEcash] Create Ecash: $encodedToken');
    return CashuResponse.fromSuccessData(encodedToken);
  }

  static Future<CashuResponse<(String memo, int amount)>> redeemEcash({
    required String ecashString,
    List<String> redeemPrivateKey = const [],
    SignWithKeyFunction? signFunction,
  }) async {

    await CashuManager.shared.setupFinish.future;

    final token = TokenHelper.getDecodedToken(ecashString);
    if (token == null) return CashuResponse.fromErrorMsg('Invalid token');
    if (token.unit.isNotEmpty && token.unit != 'sat') return CashuResponse.fromErrorMsg('Unsupported unit');

    final memo = token.memo;
    var receiveAmount = 0;
    final mints = <String>{};

    final tokenEntry = token.token;

    return Future<CashuResponse<(String memo, int amount)>>(() async {
      for (var entry in tokenEntry) {
        final mint = await CashuManager.shared.getMint(entry.mint);
        if (mint == null) continue ;

        final proofs = [...entry.proofs];

        if (redeemPrivateKey.isNotEmpty && signFunction != null) {
          for (var proof in proofs) {
            await addSignatureToProof(
              proof: proof,
              privateKeyList: redeemPrivateKey,
              signFunction: signFunction,
            );
          }
        }

        final response = await ProofHelper.swapProofs(
          mint: mint,
          proofs: proofs,
          syncDelete: false,
        );
        if (!response.isSuccess) return response.cast();

        final newProofs = response.data;
        receiveAmount += newProofs.totalAmount;
        mints.add(mint.mintURL);
        await CashuManager.shared.updateMintBalance(mint);
      }

      if (receiveAmount > 0) {
        return CashuResponse.fromSuccessData((memo, receiveAmount));
      } else {
        return CashuResponse.fromErrorMsg('No funds available proofs for redemption.');
      }
    }).whenComplete(() async {
      if (receiveAmount > 0) {
        await HistoryStore.addToHistory(
          amount: receiveAmount,
          type: IHistoryType.eCash,
          value: ecashString,
          mints: mints.toList(),
        );
        // If it is a self-issued token, set its status to "Spent."
        (await HistoryStore.getHistory(value: [ecashString]))
            .where((history) => history.amount < 0)
            .forEach((history) {
          history.isSpent = true;
          HistoryStore.updateHistoryEntry(history);
        });
      }
    });
  }

  static Future<bool> redeemEcashFromInvoice({
    required IMint mint,
    required String pr,
  }) async {

    final req = Bolt11PaymentRequest(pr);
    for (var tag in req.tags) {
      debugPrint('[I][Cashu - invoice decode]${tag.type}: ${tag.data}');
    }
    final hash = req.tags.where((e) => e.type == 'payment_hash').firstOrNull?.data;
    if (hash == null) return false;

    final invoice = LightningInvoice(
      pr: pr,
      hash: hash,
      amount: (req.amount.toDouble() * 100000000).toInt().toString(),
      mintURL: mint.mintURL,
    );
    return CashuManager.shared.invoiceHandler.checkInvoice(invoice, true);
  }

  static Future<CashuResponse<String>> getBackUpToken(List<IMint> mints) async {
    List<TokenEntry> entryList = [];
    for (final mint in mints) {
      final response = await ProofHelper.getProofsToUse(mint: mint);
      if (!response.isSuccess) return response.cast();

      final proofs = response.data;
      if (proofs.isNotEmpty) {
        entryList.add(
          TokenEntry(
            mint: mint.mintURL,
            proofs: proofs,
          ),
        );
      }
    }
    if (entryList.isEmpty) {
      return CashuResponse.fromErrorMsg('There is no valid proof');
    }
    return CashuResponse.fromSuccessData(
      TokenHelper.getEncodedToken(
        Token(
          token: entryList,
        ),
      ),
    );
  }

  static Bolt11PaymentRequest? _tryConstructRequestFromPr(String pr) {
    pr = pr.trim();
    for (var prefix in _lnPrefix) {
      if (pr.startsWith(prefix)) {
        pr = pr.substring(prefix.length).trim();
        break; // Important to exit the loop once a match is found
      }
    }
    if (pr.isEmpty) return null;
    try {
      final req = Bolt11PaymentRequest(pr);
      for (var tag in req.tags) {
        debugPrint('[Cashu - invoice decode]${tag.type}: ${tag.data}');
      }
      return req;
    } catch (_) {
      return null;
    }
  }

  static int? amountOfLightningInvoice(String pr) {
    final request = _tryConstructRequestFromPr(pr);
    if (request == null) return null;
    return (request.amount.toDouble() * 100000000).toInt();
  }

  static CashuTokenInfo? infoOfToken(String ecashToken) {
    final token = TokenHelper.getDecodedToken(ecashToken);
    if (token == null) return null;

    final proofs = token.token.fold(<Proof>[], (pre, e) => pre..addAll(e.proofs));

    final firstProofsSecret = proofs.firstOrNull?.secret ?? '';

    return CashuTokenInfo(
      amount: token.sumProofsValue.toInt(),
      unit: token.unit,
      memo: token.memo,
      p2pkInfo: NutP2PKHelper.getInfoWithSecret(firstProofsSecret),
    );
  }


  static bool isLnInvoice(String str) {
    final request = _tryConstructRequestFromPr(str);
    return request != null;
  }

  static Future addSignatureToProof({
    required Proof proof,
    required List<String> privateKeyList,
    required SignWithKeyFunction signFunction,
  }) async {
    try {
      final witnessRaw = proof.witness;
      Map witness = {};
      if (witnessRaw.isNotEmpty) {
        witness = jsonDecode(proof.witness) as Map;
      }
      var originSign = witness['signatures'];
      if (originSign is! List) {
        originSign = [];
      }
      final signatures = [...originSign.map((e) => e.toString()).toList().cast<String>()];
      for (var privkey in privateKeyList) {
        final sign = await signFunction(privkey, proof.secret);
        signatures.add(sign);
      }
      witness['signatures'] = signatures;
      proof.witness = jsonEncode(witness);
    } catch (e, stack) {
      debugPrint('[E][Cashu - redeemEcash] $e');
      debugPrint('[E][Cashu - redeemEcash] $stack');
    }
  }

  static Future<String?> addSignatureToToken({
    required String ecashString,
    required List<String> privateKeyList,
    required SignWithKeyFunction signFunction,
  }) async {
    final tokenPackage = TokenHelper.getDecodedToken(ecashString);
    if (tokenPackage == null) return null;

    final tokenEntryList = tokenPackage.token;
    for (var entry in tokenEntryList) {
      for (var proof in entry.proofs) {
        await addSignatureToProof(
          proof: proof,
          privateKeyList: privateKeyList,
          signFunction: signFunction,
        );
      }
    }
    return TokenHelper.getEncodedToken(tokenPackage);
  }
}