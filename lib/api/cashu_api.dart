
import 'dart:async';
import 'dart:math';

import 'package:cashu_dart/business/proof/proof_helper.dart';
import 'package:cashu_dart/core/mint_actions.dart';

import '../business/proof/token_helper.dart';
import '../business/transaction/hitstory_store.dart';
import '../business/transaction/transaction_helper.dart';
import '../business/wallet/cashu_manager.dart';
import '../core/nuts/define.dart';
import '../core/nuts/nut_00.dart';
import '../model/history_entry.dart';
import '../model/invoice.dart';
import '../model/invoice_listener.dart';
import '../model/mint_info.dart';
import '../model/mint_model.dart';
import '../utils/network/response.dart';
import 'general_client.dart';
import 'v0/client.dart';
import 'v1/client.dart';

final CashuAPI Cashu = CashuAPI();

class CashuAPI {

  /**************************** Financial ****************************/
  /// Calculate the total balance across all mints.
  int totalBalance() {
    final mints = [...CashuManager.shared.mints];
    return mints.fold(0, (pre, mint) => pre + mint.balance);
  }

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
  Future<int?> checkProofsAvailable(IMint mint) async {

    await CashuManager.shared.setupFinish.future;

    final proofs = await ProofHelper.getProofs(mint.mintURL);
    final response = await mint.tokenCheckAction(mintURL: mint.mintURL, proofs: proofs);
    if (!response.isSuccess) return null;
    if (response.data.length != proofs.length) {
      throw Exception('[E][Cashu - checkProofsAvailable] '
          'The length of states(${response.data.length}) and proofs(${proofs.length}) is not consistent');
    }

    var validAmount = 0;
    var burnedAmount = 0;
    final burnedProofs = <Proof>[];

    for (int i = 0; i < response.data.length; i++) {
      final proof = proofs[i];
      switch (response.data[i]) {
        case TokenState.live:
          validAmount += proof.amountNum;
          break ;
        case TokenState.burned:
          burnedAmount += proof.amountNum;
          burnedProofs.add(proof);
          break ;
        case TokenState.inFlight:
          break ;
      }
    }

    mint.balance = validAmount;
    await CashuManager.shared.updateMintBalance(mint);
    await ProofHelper.deleteProofs(proofs: burnedProofs, mint: null);

    return burnedAmount;
  }

  /// Retrieves all 'used' proofs for a given mint.
  Future<List<Proof>> getAllUseProofs(IMint mint) {
    return ProofHelper.getProofs(mint.mintURL);
  }

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

    final success = await CashuManager.shared.invoiceHandler.checkInvoice(receipt, true);
    if (success) return CashuResponse.fromSuccessData(receipt);

    // Fetch again
    isRedeemed = await HistoryStore.hasReceiptRedeemHistory(receipt);
    if (isRedeemed) return CashuResponse.fromSuccessData(receipt);

    return CashuResponse.generalError();
  }

  /**************************** Mint ****************************/
  /// Returns a list of all mints.
  Future<List<IMint>> mintList() async {
    await CashuManager.shared.setupFinish.future;
    return CashuManager.shared.mints;
  }

  /// Adds a new mint with the given URL.
  /// Throws an exception if the URL does not start with 'https://'.
  /// Returns the newly added mint, or null if the operation fails.
  Future<IMint?> addMint(String mintURL) async {
    await CashuManager.shared.setupFinish.future;
    return await CashuManager.shared.addMint(mintURL);
  }

  /// Deletes the specified mint.
  /// Returns true if the deletion is successful.
  Future<bool> deleteMint(IMint mint) async {
    await CashuManager.shared.setupFinish.future;
    return CashuManager.shared.deleteMint(mint);
  }

  /// Edits the name of the specified mint.
  Future editMintName(IMint mint, String name) async {
    await CashuManager.shared.setupFinish.future;
    if (mint.name == name) return ;
    mint.name = name;
    CashuManager.shared.updateMintName(mint);
  }

  /// Retrieves mint information from the specified mint.
  Future<CashuResponse<MintInfo>> fetchMintInfo(IMint mint) {
    return mint.requestMintInfoAction(mintURL: mint.mintURL);
  }

  /**************************** Transaction ****************************/
  /// Sends e-cash using the provided mint and amount.
  ///
  /// [mint]: The mint object to use for sending e-cash.
  /// [amount]: The amount of e-cash to send.
  /// [memo]: An optional memo for the transaction.
  ///
  /// Returns the encoded token if successful, otherwise null.
  Future<CashuResponse<String>> sendEcash({
    required IMint mint,
    required int amount,
    String memo = '',
    String unit = 'sat',
    List<Proof>? proofs,
  }) => CashuAPIGeneralClient.sendEcash(
    mint: mint,
    amount: amount,
    memo: memo,
    unit: unit,
    proofs: proofs,
  );

  /// Sends a list of e-cash amounts using the provided mint.
  Future<CashuResponse<List<String>>> sendEcashList({
    required IMint mint,
    required List<int> amountList,
    List<String> publicKeys = const [],
    List<String>? refundPubKeys,
    int? locktime,
    int? signNumRequired,
    String memo = '',
    String unit = 'sat',
  }) => CashuAPIGeneralClient.sendEcashList(
    mint: mint,
    amountList: amountList,
    publicKeys: publicKeys,
    refundPubKeys: refundPubKeys,
    locktime: locktime,
    signNumRequired: signNumRequired,
    memo: memo,
    unit: unit,
  );

  /// Sends e-cash to specified recipients identified by their public keys.
  ///
  /// [mint]: The mint object to use for sending e-cash.
  /// [amount]: The amount of e-cash to send.
  /// [publicKeys]: A list of public keys representing the recipients of the e-cash.
  /// [refundPubKeys]: Optional public keys for refunds after [locktime].
  /// [locktime]: Optional timestamp (seconds) for when the e-cash becomes refundable.
  /// [memo]: An optional memo for the transaction.
  /// [unit]: The unit of the e-cash to be sent. Default is 'sat'.
  /// [proofs]: An optional list of proofs for transaction verification.
  ///
  /// Returns the encoded token if successful, otherwise null.
  Future<CashuResponse<String>> sendEcashToPublicKeys({
    required IMint mint,
    required int amount,
    required List<String> publicKeys,
    List<String>? refundPubKeys,
    int? locktime,
    int? signNumRequired,
    String memo = '',
    String unit = 'sat',
  }) => CashuAPIGeneralClient.sendEcashToPublicKeys(
    mint: mint,
    amount: amount,
    publicKeys: publicKeys,
    refundPubKeys: refundPubKeys,
    locktime: locktime,
    signNumRequired: signNumRequired,
    memo: memo,
    unit: unit,
  );

  /// Redeems e-cash from the given string.
  /// [ecashString]: The string representing the e-cash.
  /// Returns a tuple containing memo and amount if successful.
  Future<CashuResponse<(String memo, int amount)>> redeemEcash({
    required String ecashString,
    List<String> redeemPrivateKey = const [],
    SignWithKeyFunction? signFunction,
  }) => CashuAPIGeneralClient.redeemEcash(
    ecashString: ecashString,
    redeemPrivateKey: redeemPrivateKey,
    signFunction: signFunction,
  );

  Future<bool> redeemEcashFromInvoice({
    required IMint mint,
    required String pr,
  }) => CashuAPIGeneralClient.redeemEcashFromInvoice(mint: mint, pr: pr);

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
  }) {
    if (mint.maxNutsVersion >= 1) {
      return CashuAPIV1Client.payingLightningInvoice(mint: mint, pr: pr);
    }
    return CashuAPIV0Client.payingLightningInvoice(mint: mint, pr: pr);
  }

  /// Creates a Lightning invoice with the given amount.
  ///
  /// [mint]: The mint to issue the invoice.
  /// [amount]: The amount for the invoice.
  ///
  /// Returns the created invoice object if successful, otherwise null.
  Future<Receipt?> createLightningInvoice({
    required IMint mint,
    required int amount,
  }) {
    return TransactionHelper.requestCreateInvoice(
      mint: mint,
      amount: amount,
    );
  }

  /// Adds an invoice listener.
  void addInvoiceListener(CashuListener listener)  {
    CashuManager.shared.addListener(listener);
  }

  /// Removes an invoice listener.
  void removeInvoiceListener(CashuListener listener)  {
    CashuManager.shared.removeListener(listener);
  }

  Future<CashuResponse<String>> getBackUpToken(List<IMint> mints) =>
      CashuAPIGeneralClient.getBackUpToken(mints);

  /**************************** Tools ****************************/
  /// Converts the amount in a Lightning Network payment request to satoshis.
  /// [pr]: BOLT11 encoded payment request string.
  /// Returns the amount from the payment request in satoshis as an integer, or null if the
  /// payment request is invalid or processing fails.
  int? amountOfLightningInvoice(String pr) =>
      CashuAPIGeneralClient.amountOfLightningInvoice(pr);

  /// Retrieves information of a token from its e-cash token string.
  ///
  /// [ecashToken]: The e-cash token string.
  ///
  /// Returns a tuple of memo and total amount if successful, otherwise null.
  (String memo, int amount, List secretData)? infoOfToken(String ecashToken) =>
      CashuAPIGeneralClient.infoOfToken(ecashToken);

  /// Checks if a given string is a valid Cashu token.
  bool isCashuToken(String str) {
    return Nut0.decodedToken(str) != null;
  }

  /// Determines if a given string is a valid Lightning Network (LN) invoice.
  /// Strips common URI prefixes before validation.
  bool isLnInvoice(String str) => CashuAPIGeneralClient.isLnInvoice(str);

  Future<String?> addSignatureToToken({
    required String ecashString,
    required List<String> privateKeyList,
    required SignWithKeyFunction signFunction,
  }) =>
      CashuAPIGeneralClient.addSignatureToToken(
        ecashString: ecashString,
        privateKeyList: privateKeyList,
        signFunction: signFunction,
      );
}