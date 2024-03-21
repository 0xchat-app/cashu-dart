
import 'dart:convert';

import 'package:bolt11_decoder/bolt11_decoder.dart';
import 'package:flutter/foundation.dart';

import '../business/proof/proof_helper.dart';
import '../business/proof/proof_store.dart';
import '../business/proof/token_helper.dart';
import '../business/transaction/hitstory_store.dart';
import '../business/wallet/cashu_manager.dart';
import '../core/nuts/nut_00.dart';
import '../model/history_entry.dart';
import '../model/lightning_invoice.dart';
import '../model/mint_model.dart';
import '../utils/network/response.dart';

typedef SignWithKeyFunction = Future<String> Function(String key, String message);

class CashuAPIGeneralClient {

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

    await ProofHelper.deleteProofs(proofs: proofs, mint: null);
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
      await ProofHelper.deleteProofs(proofs: proofs, mint: null);
    }

    return CashuResponse.fromSuccessData(tokenList);
  }

  static Future<CashuResponse<String>> sendEcashToPublicKeys({
    required IMint mint,
    required int amount,
    required List<String> publicKeys,
    List<String>? refundPubKeys,
    int? locktime,
    int? signNumRequired,
    String memo = '',
    String unit = 'sat',
  }) async {

    await CashuManager.shared.setupFinish.future;

    if (publicKeys.isEmpty) {
      return CashuResponse.fromErrorMsg('PublicKeys is empty.');
    }

    // get proofs
    final response = await ProofHelper.getProofsToUse(
      mint: mint,
      amount: BigInt.from(amount),
    );
    if (!response.isSuccess) return response.cast();

    final localProofs = response.data;
    final swapResponse = await ProofHelper.swapProofsForP2PK(
      mint: mint,
      proofs: localProofs,
      publicKeys: publicKeys,
      refundPubKeys: refundPubKeys,
      locktime: locktime,
      signNumRequired: signNumRequired,
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

    await ProofHelper.deleteProofs(proofs: p2pkProofs, mint: null);
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

  static int? amountOfLightningInvoice(String pr) {
    try {
      final req = Bolt11PaymentRequest(pr);
      for (var tag in req.tags) {
        debugPrint('[Cashu - invoice decode]${tag.type}: ${tag.data}');
      }
      return (req.amount.toDouble() * 100000000).toInt();
    } catch (_) {
      return null;
    }
  }

  static (String memo, int amount, List secretData)? infoOfToken(String ecashToken) {
    final token = TokenHelper.getDecodedToken(ecashToken);
    if (token == null) return null;
    final proofs = token.token.fold(<Proof>[], (pre, e) => pre..addAll(e.proofs));

    List secretData = [];
    try {
      secretData = jsonDecode( proofs.firstOrNull?.secret ?? '');
    } catch (_) { }

    return (token.memo, proofs.totalAmount, secretData);
  }


  static bool isLnInvoice(String str) {
    if (str.isEmpty) return false;

    str = str.trim();
    final uriPrefixes = [
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
    for (var prefix in uriPrefixes) {
      if (str.startsWith(prefix)) {
        str = str.substring(prefix.length).trim();
        break; // Important to exit the loop once a match is found
      }
    }
    if (str.isEmpty) return false;

    try {
      Bolt11PaymentRequest(str);
    } catch (_) {
      return false;
    }
    return true;
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