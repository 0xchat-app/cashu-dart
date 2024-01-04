
import 'package:cashu_dart/business/proof/proof_store.dart';
import 'package:cashu_dart/core/keyset_store.dart';
import 'package:cashu_dart/utils/tools.dart';

import '../../core/nuts/nut_00.dart';
import '../../core/nuts/v1/nut_07.dart';

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
      final states = await Nut7.requestTokenState(mintURL: mintURL, proofs: proofs);
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
      final states = await Nut7.requestTokenState(mintURL: mintURL, proofs: proofs);
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