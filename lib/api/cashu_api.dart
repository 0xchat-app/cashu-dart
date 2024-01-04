
import 'dart:async';

import '../core/nuts/nut_00.dart';
import '../model/history_entry.dart';
import '../model/invoice.dart';
import '../model/invoice_listener.dart';
import '../model/mint_model.dart';
import 'v0/client.dart';
import 'v1/client.dart';

final CashuAPIClient Cashu = CashuAPIV0Client();

abstract class CashuAPIClient {

  bool get isV1 => this is CashuAPIV1Client;

  /**************************** Financial ****************************/
  /// Calculate the total balance across all mints.
  int totalBalance();

  /// Get a list of history entries with pagination support.
  /// [size]: Number of entries to return.
  /// [lastHistoryId]: The ID of the last history entry from the previous fetch.
  Future<List<IHistoryEntry>> getHistoryList({
    int size = 10,
    String lastHistoryId = '',
  });

  /// Check the availability of proofs for a given mint.
  /// Returns the amount of invalid proof, or null if the request fails.
  Future<int?> checkProofsAvailable(IMint mint);

  Future<List<Proof>> getAllUseProofs(IMint mint);


  /**************************** Mint ****************************/
  /// Returns a list of all mints.
  List<IMint> mintList();

  /// Adds a new mint with the given URL.
  /// Throws an exception if the URL does not start with 'https://'.
  /// Returns the newly added mint, or null if the operation fails.
  Future<IMint?> addMint(String mintURL);

  /// Deletes the specified mint.
  /// Returns true if the deletion is successful.
  Future<bool> deleteMint(IMint mint);

  /// Edits the name of the specified mint.
  Future editMintName(IMint mint, String name);

  /**************************** Transaction ****************************/
  /// Sends e-cash using the provided mint and amount.
  /// [mint]: The mint object to use for sending e-cash.
  /// [amount]: The amount of e-cash to send.
  /// [memo]: An optional memo for the transaction.
  /// Returns the encoded token if successful, otherwise null.
  Future<String?> sendEcash({
    required IMint mint,
    required int amount,
    String memo = '',
  });

  /// Redeems e-cash from the given string.
  /// [ecashString]: The string representing the e-cash.
  /// Returns a tuple containing memo and amount if successful, otherwise null.
  Future<(String memo, int amount)?> redeemEcash(String ecashString);

  /// Processes payment of a Lightning invoice.
  /// [mint]: The mint to use for payment.
  /// [pr]: The payment request string of the Lightning invoice.
  /// [amount]: The amount to pay.
  /// Returns true if payment is successful.
  Future<bool> payingLightningInvoice({
    required IMint mint,
    required String pr,
  });

  /// Creates a Lightning invoice with the given amount.
  /// [mint]: The mint to issue the invoice.
  /// [amount]: The amount for the invoice.
  /// Returns the created invoice object if successful, otherwise null.
  Future<Receipt?> createLightningInvoice({
    required IMint mint,
    required int amount,
  });

  void addInvoiceListener(InvoiceListener listener);

  void removeInvoiceListener(InvoiceListener listener);
}