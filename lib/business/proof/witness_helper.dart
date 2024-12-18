
import 'dart:convert';

import '../../core/nuts/token/proof_isar.dart';
import '../../utils/log_util.dart';
import '../wallet/cashu_manager.dart';

class WitnessHelper {
  static Future addP2PKWitnessToProof({
    required ProofIsar proof,
    P2PKWitnessParam? param,
  }) async {
    final pubkeyList = param?.pubkeyList ?? [];
    final defaultKey = CashuManager.shared.defaultSignPubkey?.call() ?? '';
    final immutablePubkeyList = [
      ...pubkeyList,
      if (defaultKey.isNotEmpty)
        defaultKey
    ].toSet();
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
      LogUtils.e(() => '[WitnessHelper - addP2PKWitnessToProof] $e');
      LogUtils.e(() => '[WitnessHelper - addP2PKWitnessToProof] $stack');
    }
  }

  static Future addHTLCWitnessToProof({
    required ProofIsar proof,
    HTLCWitnessParam? param,
  }) async {

    var pubkey = param?.pubkey ?? '';
    if (pubkey.isEmpty) {
      pubkey = CashuManager.shared.defaultSignPubkey?.call() ?? '';
    }
    try {
      final witnessRaw = proof.witness;
      Map witness = {};
      if (witnessRaw.isNotEmpty) {
        witness = jsonDecode(witnessRaw) as Map;
      }

      // Signature
      witness['signature'] ??= await CashuManager.shared.signFn?.call(pubkey, proof.secret);
      final signature = witness['signature'];
      if (signature is! String || signature.isEmpty) {
        witness.remove('signature');
      }

      // Preimage
      if (witness.isNotEmpty) {
        proof.witness = jsonEncode(witness);
      }
    } catch (e, stack) {
      LogUtils.e(() => '[WitnessHelper - addHTLCWitnessToProof] $e');
      LogUtils.e(() => '[WitnessHelper - addHTLCWitnessToProof] $stack');
    }
  }
}

abstract class WitnessParam {}

class P2PKWitnessParam extends WitnessParam {
  P2PKWitnessParam({
    this.pubkeyList = const [],
  });
  final List<String> pubkeyList;
}

class HTLCWitnessParam extends WitnessParam {
  HTLCWitnessParam({
    this.pubkey = '',
  });
  final String pubkey;
}