
import 'package:cashu_dart/utils/list_extension.dart';

import '../../core/nuts/DHKE.dart';
import '../../core/nuts/nut_00.dart';
import '../../model/history_entry.dart';
import '../../model/mint_model.dart';
import '../../model/unblinding_data.dart';
import '../../utils/network/response.dart';
import '../../utils/task_scheduler.dart';
import '../proof/keyset_helper.dart';
import '../proof/proof_store.dart';
import '../proof/unblinding_data_store.dart';
import '../transaction/hitstory_store.dart';

export '../../model/unblinding_data.dart';

typedef UnblindingDataPayload = (
  IMint mint,
  String unit,
  List<BlindedSignature> signatures,
  List<String> secrets,
  List<BigInt> rs,
  ProofBlindingAction action,
  String actionValue,
);

class ProofBlindingManager {
  static final ProofBlindingManager shared = ProofBlindingManager._internal();

  TaskScheduler? unblindingDataChecker;

  ProofBlindingManager._internal();

  Future<void> initialize() async {
    unblindingDataChecker = TaskScheduler(task: _unblindingDataCheck)..start();
    unblindingDataChecker?.initComplete();
  }

  void dispose() {
    unblindingDataChecker?.dispose();
  }

  Future<CashuResponse<List<Proof>>> unblindingBlindedSignature(
    UnblindingDataPayload payload,
  ) async {

    final (mint, unit, signatures, secrets, rs, action, actionValue) = payload;

    if (signatures.isEmpty) return CashuResponse.fromSuccessData([]);

    List<UnblindingData> unblindingDataList = [];
    for (var i = 0; i < signatures.length; i++) {
      final signature = signatures[i];
      BigInt? r;
      if (rs.length > i) {
        r = rs[i];
      }
      String secret = '';
      if (secrets.length > i) {
        secret = secrets[i];
      }

      final unblindingData = UnblindingData.fromSignature(
        signature: signature,
        mintURL: mint.mintURL,
        action: action,
        actionValue: actionValue,
        unit: unit,
        r: r?.toString() ?? '',
        secret: secret,
      );
      unblindingDataList.add(unblindingData);
    }

    await UnblindingDataStore.add(unblindingDataList);

    final proofs = await DHKE.constructProofs(
      data: unblindingDataList,
      keysFetcher: KeysetHelper.keysetFetcher,
    );

    if (proofs == null) {
      return CashuResponse.fromErrorMsg('Unblinding: proofs is null.');
    }

    final isAddProofSuccess = await ProofStore.addProofs(proofs);
    if (!isAddProofSuccess) return CashuResponse.fromErrorMsg('Unblinding: add proof error.');

    await UnblindingDataStore.delete(unblindingDataList);

    return CashuResponse.fromSuccessData(proofs);
  }

  Future _unblindingDataCheck() async {
    final unblindingDataList = await UnblindingDataStore.getData();

    final unblindingDataMap = unblindingDataList.groupBy((e) => e.actionValue);
    final actionValues = unblindingDataMap.keys;

    for (var actionValue in actionValues) {
      final data = unblindingDataMap[actionValue];
      if (data == null || data.isEmpty) continue ;

      final proofs = await DHKE.constructProofs(
        data: data,
        keysFetcher: KeysetHelper.keysetFetcher,
      );

      if (proofs == null) continue ;

      final isAddProofSuccess = await ProofStore.addProofs(proofs);
      if (!isAddProofSuccess) continue ;

      await HistoryStore.addToHistory(
        amount: proofs.totalAmount,
        type: data.first.actionType.asHistoryType(),
        value: actionValue,
        mints: data.map((e) => e.mintURL).toSet().toList(),
      );
      await UnblindingDataStore.delete(unblindingDataList);
    }
  }
}

extension ProofBlindingActionEx on ProofBlindingAction {
  IHistoryType asHistoryType() {
    switch (this) {
      case ProofBlindingAction.unknown:
        return IHistoryType.unknown;
      case ProofBlindingAction.minting:
      case ProofBlindingAction.melt:
        return IHistoryType.lnInvoice;
      case ProofBlindingAction.multiMintSwap:
      case ProofBlindingAction.swapForP2PK:
        return IHistoryType.swapForP2PK;
    }
  }
}