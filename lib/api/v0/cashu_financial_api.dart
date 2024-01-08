
import 'dart:math';

import '../../business/proof/proof_helper.dart';
import '../../business/transaction/hitstory_store.dart';
import '../../business/wallet/cashu_manager.dart';
import '../../core/nuts/define.dart';
import '../../core/nuts/nut_00.dart';
import '../../model/history_entry.dart';
import '../../model/mint_model.dart';


class CashuFinancialAPI {
  /// Calculate the total balance across all mints.
  static int totalBalance() {
    final mints = [...CashuManager.shared.mints];
    return mints.fold(0, (pre, mint) => pre + mint.balance);
  }

  /// Get a list of history entries with pagination support.
  /// [size]: Number of entries to return.
  /// [lastHistoryId]: The ID of the last history entry from the previous fetch.
  static Future<List<IHistoryEntry>> getHistoryList({
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

  /// Check the availability of proofs for a given mint.
  /// Returns the amount of invalid proof, or null if the request fails.
  static Future<int?> checkProofsAvailable(IMint mint) async {
    await CashuManager.shared.setupFinish.future;
    final proofs = await ProofHelper.getProofs(mint.mintURL);
    final response = await ProofHelper.checkAction(mintURL: mint.mintURL, proofs: proofs);
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
    await ProofHelper.deleteProofs(proofs: burnedProofs, mintURL: null);

    return burnedAmount;
  }

  static Future<List<Proof>> getAllUseProofs(IMint mint) {
    return ProofHelper.getProofs(mint.mintURL);
  }
}