
import 'package:cashu_dart/business/wallet/cashu_manager.dart';
import 'package:cashu_dart/core/mint_actions.dart';

import '../../core/DHKE_helper.dart';
import '../../core/nuts/DHKE.dart';
import '../../core/nuts/nut_00.dart';
import '../../model/mint_model.dart';
import '../../model/unblinding_data.dart';
import '../../utils/network/response.dart';
import '../mint/mint_helper.dart';
import '../proof/keyset_helper.dart';
import '../proof/proof_store.dart';
import '../proof/unblinding_data_store.dart';

typedef UnblindingDataPayload = (
  IMint mint,
  String unit,
  List<BlindedSignature> signatures,
  List<String> secrets,
  List<BigInt> rs,
);

class EcashManager {
  static final EcashManager shared = EcashManager._internal();
  EcashManager._internal();

  Future<CashuResponse<List<Proof>>> unblindingBlindedSignature(UnblindingDataPayload payload) async {

    final (mint, unit, signatures, secrets, rs) = payload;

    if (signatures.isEmpty ||
        signatures.length != secrets.length ||
        signatures.length != rs.length) {
      return CashuResponse.fromErrorMsg('Data length error: '
          '${signatures.length}(signatures), '
          '${secrets.length}(secrets), '
          '${rs.length}(rs)');
    }

    List<UnblindingData> unblindingDataList = [];
    for (var i = 0; i < signatures.length; i++) {
      final signature = signatures[i];
      final r = rs[i];
      final secret = secrets[i];

      final unblindingData = UnblindingData.fromSignature(
        signature: signature,
        mintURL: mint.mintURL,
        unit: unit,
        r: r.toString(),
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
      return CashuResponse.fromErrorMsg('Unblinding error.');
    }

    await ProofStore.addProofs(proofs);
    await UnblindingDataStore.delete(unblindingDataList);
    await CashuManager.shared.updateMintBalance();

    return CashuResponse.fromSuccessData(proofs);
  }
}