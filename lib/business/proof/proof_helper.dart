
import 'package:cashu_dart/utils/tools.dart';

import '../../api/cashu_api.dart';
import '../../core/keyset_store.dart';
import '../../core/nuts/define.dart';
import '../../core/nuts/nut_00.dart';
import '../../core/nuts/v0/nut.dart' as v0;
import '../../core/nuts/v1/nut.dart' as v1;
import 'proof_store.dart';

typedef TokenCheckAction = Future<List<TokenState>?> Function({
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

  static Future<(List<Proof> usableProofs, List<Proof> unusableProofs)?> getProofsToUse({
    required String mintURL,
    required BigInt amount,
    bool orderAsc = false,
    List<Proof>? proofs,
    bool checkState = true,
  }) async {
    proofs ??= await getProofs(mintURL, orderAsc);

    // check state
    if (checkState) {
      final states = await checkAction(mintURL: mintURL, proofs: proofs);
      if (states == null) return null;
      if (states.length != proofs.length) {
        throw Exception('[E][Cashu - checkProofsAvailable] '
            'The length of states(${states.length}) and proofs(${proofs.length}) is not consistent');
      }

      // get usable proofs
      final usableProofs = <Proof>[];
      for (int i = 0; i < proofs.length; i++) {
        if (states[i] == TokenState.live) {
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

    return (proofsToSend, proofsToKeep);
  }

  static deleteProofs({
    required List<Proof> proofs,
    required String? mintURL,
  }) async {
    final burnedProofs = <Proof>[];
    if (mintURL != null && mintURL.isNotEmpty) {
      final states = await checkAction(mintURL: mintURL, proofs: proofs);
      if (states == null) return null;
      if (states.length != proofs.length) {
        throw Exception('[E][Cashu - checkProofsAvailable] '
            'The length of states(${states.length}) and proofs(${proofs.length}) is not consistent');
      }
      for (int i = 0; i < proofs.length; i++) {
        if (states[i] == TokenState.burned) {
          burnedProofs.add(proofs[i]);
        }
      }
    } else {
      burnedProofs.addAll(proofs);
    }

    await ProofStore.deleteProofs(burnedProofs);
  }
}