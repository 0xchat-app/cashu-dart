
import 'dart:async';
import 'dart:math';

import 'package:bolt11_decoder/bolt11_decoder.dart';
import 'package:cashu_dart/business/proof/proof_helper.dart';
import 'package:cashu_dart/business/proof/proof_store.dart';

import '../business/mint/mint_helper.dart';
import '../business/proof/token_helper.dart';
import '../business/transaction/hitstory_store.dart';
import '../business/wallet/cashu_manager.dart';
import '../business/wallet/invoice_handler.dart';
import '../core/nuts/nut_00.dart';
import '../model/history_entry.dart';
import '../model/invoice.dart';
import '../model/invoice_listener.dart';
import '../model/mint_info.dart';
import '../model/mint_model.dart';
import '../utils/network/response.dart';
import 'v0/client.dart';
import 'v1/client.dart';

final CashuAPIClient Cashu = CashuAPIV0Client();

abstract class CashuAPIClient {

  bool get isV1 => this is CashuAPIV1Client;

  /**************************** Financial ****************************/
  /// Calculate the total balance across all mints.
  int totalBalance();

  /// Get a list of history entries with pagination support.
  ///
  /// [size]: Number of entries to return.
  /// [lastHistoryId]: The ID of the last history entry from the previous fetch.
  Future<List<IHistoryEntry>> getHistoryList({
    int size = 10,
    String lastHistoryId = '',
  }) async {
    await CashuManager.shared.setupFinish.future;
    final allHistory = await HistoryStore.getHistory();

    var startIndex = 0;
    if (lastHistoryId.isNotEmpty) {
      final index = allHistory.indexWhere((element) => element.id == lastHistoryId);
      if (index >= 0) {
        startIndex = index + 1;
      }
    }
    final end = min(allHistory.length, startIndex + size);
    return allHistory.sublist(startIndex, end);
  }

  Future<List<IHistoryEntry>> getHistory({
    List<String> value = const [],
  }) async {
    await CashuManager.shared.setupFinish.future;
    return await HistoryStore.getHistory(value: value);
  }

  /// Check the availability of proofs for a given mint.
  /// Returns the amount of invalid proof, or null if the request fails.
  Future<int?> checkProofsAvailable(IMint mint);

  /// Retrieves all 'used' proofs for a given mint.
  Future<List<Proof>> getAllUseProofs(IMint mint);

  /// Determines the spendability of an eCash token from a given history entry.
  ///
  /// Extracts the eCash token from [entry] and checks if it is spendable.
  /// Returns `true` if the token is spendable, `false` if not, or `null` if the status is indeterminable.
  Future<bool?> isEcashTokenSpendableFromHistory(IHistoryEntry entry) async {
    if (entry.type != IHistoryType.eCash) return null;

    final spendable = await isEcashTokenSpendableFromToken(entry.value);
    if (spendable == null) return null;

    entry.isSpent = !spendable;
    if (entry.isSpent == true) {
      await HistoryStore.updateHistoryEntry(entry);
    }
    return spendable;
  }

  Future<bool?> isEcashTokenSpendableFromToken(String token) async {
    if (!isCashuToken(token)) return null;

    final spendable = await TokenHelper.isTokenSpendable(token);
    if (spendable == null) return null;

    return spendable;
  }

  Future<CashuResponse<Receipt>> checkReceiptCompleted(Receipt receipt) async {

    var isRedeemed = await HistoryStore.hasReceiptRedeemHistory(receipt);
    if (isRedeemed) return CashuResponse.fromSuccessData(receipt);

    final success = await InvoiceHandler().checkInvoice(receipt, true);
    if (success) return CashuResponse.fromSuccessData(receipt);

    // Fetch again
    isRedeemed = await HistoryStore.hasReceiptRedeemHistory(receipt);
    if (isRedeemed) return CashuResponse.fromSuccessData(receipt);

    return CashuResponse.generalError();
  }

  /**************************** Mint ****************************/
  /// Returns a list of all mints.
  Future<List<IMint>> mintList();

  /// Adds a new mint with the given URL.
  /// Throws an exception if the URL does not start with 'https://'.
  /// Returns the newly added mint, or null if the operation fails.
  Future<IMint?> addMint(String mintURL) async {
    await CashuManager.shared.setupFinish.future;
    return await CashuManager.shared.addMint(mintURL);
  }

  /// Deletes the specified mint.
  /// Returns true if the deletion is successful.
  Future<bool> deleteMint(IMint mint);

  /// Edits the name of the specified mint.
  Future editMintName(IMint mint, String name);

  /// Retrieves mint information from the specified mint.
  Future<CashuResponse<MintInfo>> fetchMintInfo(IMint mint) {
    return MintHelper.requestMintInfo(mintURL: mint.mintURL);
  }

  /**************************** Transaction ****************************/
  /// Sends e-cash using the provided mint and amount.
  /// [mint]: The mint object to use for sending e-cash.
  /// [amount]: The amount of e-cash to send.
  /// [memo]: An optional memo for the transaction.
  /// Returns the encoded token if successful, otherwise null.
  Future<CashuResponse<String>> sendEcash({
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
        memo: memo.isNotEmpty ? memo : 'Sent via 0xChat.',
        unit: unit,
      ),
    );

    await HistoryStore.addToHistory(
      amount: -amount,
      type: IHistoryType.eCash,
      value: encodedToken,
      mints: [mint.mintURL],
    );

    await ProofHelper.deleteProofs(proofs: proofs, mintURL: null);
    await CashuManager.shared.updateMintBalance(mint);

    print('[I][Cashu - sendEcash] Create Ecash: $encodedToken');
    return CashuResponse.fromSuccessData(encodedToken);
  }

  Future<CashuResponse<List<String>>> sendEcashList({
    required IMint mint,
    required List<int> amountList,
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

      final proofs = response.data;
      final encodedToken = TokenHelper.getEncodedToken(
        Token(
          token: [TokenEntry(mint: mint.mintURL, proofs: proofs)],
          memo: memo.isNotEmpty ? memo : 'Sent via 0xChat.',
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
      await ProofHelper.deleteProofs(proofs: proofs, mintURL: null);
    }

    return CashuResponse.fromSuccessData(tokenList);
  }

  /// Redeems e-cash from the given string.
  /// [ecashString]: The string representing the e-cash.
  /// Returns a tuple containing memo and amount if successful.
  Future<CashuResponse<(String memo, int amount)>> redeemEcash(String ecashString);

  /// Processes payment of a Lightning invoice.
  ///
  /// [mint]: The mint to use for payment.
  /// [pr]: The payment request string of the Lightning invoice.
  /// [amount]: The amount to pay.
  ///
  /// Returns true if payment is successful.
  Future<bool> payingLightningInvoice({
    required IMint mint,
    required String pr,
  });

  /// Creates a Lightning invoice with the given amount.
  ///
  /// [mint]: The mint to issue the invoice.
  /// [amount]: The amount for the invoice.
  ///
  /// Returns the created invoice object if successful, otherwise null.
  Future<Receipt?> createLightningInvoice({
    required IMint mint,
    required int amount,
  });

  /// Adds an invoice listener.
  void addInvoiceListener(CashuListener listener);

  /// Removes an invoice listener.
  void removeInvoiceListener(CashuListener listener);

  Future<CashuResponse<String>> getBackUpToken(List<IMint> mints) async {
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

  /**************************** Tools ****************************/
  /// Converts the amount in a Lightning Network payment request to satoshis.
  /// [pr]: BOLT11 encoded payment request string.
  /// Returns the amount from the payment request in satoshis as an integer, or null if the
  /// payment request is invalid or processing fails.
  int? amountOfLightningInvoice(String pr) {
    try {
      final req = Bolt11PaymentRequest(pr);
      for (var tag in req.tags) {
        print('[Cashu - invoice decode]${tag.type}: ${tag.data}');
      }
      return (req.amount.toDouble() * 100000000).toInt();
    } catch (_) {
      return null;
    }
  }
  /// Retrieves information of a token from its e-cash token string.
  /// [ecashToken]: The e-cash token string.
  /// Returns a tuple of memo and total amount if successful, otherwise null.
  (String memo, int amount)? infoOfToken(String ecashToken) {
    final token = TokenHelper.getDecodedToken(ecashToken);
    if (token == null) return null;
    final proofs = token.token.fold(<Proof>[], (pre, e) => pre..addAll(e.proofs));
    return (token.memo, proofs.totalAmount);
  }

  /// Checks if a given string is a valid Cashu token.
  bool isCashuToken(String str) {
    return Nut0.decodedToken(str) != null;
  }

  /// Determines if a given string is a valid Lightning Network (LN) invoice.
  /// Strips common URI prefixes before validation.
  bool isLnInvoice(String str) {
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
}