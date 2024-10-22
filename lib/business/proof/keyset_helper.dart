
import 'package:cashu_dart/core/nuts/v1/nut_02.dart';

import '../../core/keyset_store.dart';
import '../../core/nuts/define.dart';
import '../../model/keyset_info.dart';
import '../../model/mint_model.dart';
import '../mint/mint_helper.dart';
import '../wallet/cashu_manager.dart';

class KeysetHelper {

  /// Obtain the keyset of mint corresponding to the unit.
  /// If the local data is not available, obtain it from the remote endpoint
  static Future<KeysetInfo?> tryGetMintKeysetInfo(IMint mint, String unit, [String? keysetId]) async {
    keysetId ??= mint.keysetId(unit);
    // from local
    final keysets = await KeysetStore.getKeyset(mintURL: mint.mintURL, id: keysetId, unit: unit);
    var keysetInfo = findBetterKeyset(keysets);

    if (keysetInfo == null || keysetInfo.keyset.isEmpty) {
      // from remote
      final newKeysets = await MintHelper.fetchKeysetFromRemote(mint, keysetId);
      keysetInfo = findBetterKeyset(newKeysets.where((element) => element.unit == unit).toList());
    }
    if (keysetInfo == null) return null;

    // update mint keysetId
    if (keysetInfo.keyset.isNotEmpty) {
      mint.updateKeysetId(keysetInfo.id, unit);
    }

    return keysetInfo;
  }

  static KeysetInfo? findBetterKeyset(List<KeysetInfo> keysetList) {
    if (keysetList.isEmpty) return null;

    for (var keyset in keysetList) {
      if (Nut2.isHexKeysetId(keyset.id)) return keyset;
    }
    return keysetList.firstOrNull;
  }

  static Future<MintKeys?> keysetFetcher(String mintURL, String unit, String keysetId) async {
    final mint = await CashuManager.shared.getMint(mintURL);
    if (mint == null) return null;

    final info = await tryGetMintKeysetInfo(mint, unit, keysetId);
    if (info?.keyset.isEmpty ?? true) return null;

    return info?.keyset;
  }
}