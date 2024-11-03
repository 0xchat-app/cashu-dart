
import 'package:cashu_dart/core/mint_actions.dart';
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
    final keysets = await KeysetStore.getKeyset(mintURL: mint.mintURL, id: keysetId, unit: unit, active: true);
    var keysetInfo = findBetterKeyset(keysets);

    if (keysetInfo == null || keysetInfo.keyset.isEmpty) {
      // from remote
      final newKeysets = await fetchKeysetFromRemote(mint, keysetId);
      keysetInfo = findBetterKeyset(newKeysets.where((element) => element.unit == unit).toList());
    }
    if (keysetInfo == null) return null;

    // update mint keysetId
    if (keysetInfo.keyset.isNotEmpty) {
      mint.updateKeysetId(keysetInfo.id, unit);
    }

    return keysetInfo;
  }

  static Future<List<KeysetInfo>> fetchKeysetFromRemote(IMint mint, [String? keysetId]) async {

    Map<String, KeysetInfo> cache = {};

    // Fetch keysets keys
    final keysResponse = await mint.requestKeysAction(mintURL: mint.mintURL, keysetId: keysetId);
    final keys = keysResponse.isSuccess ? keysResponse.data : <MintKeysPayload>[];
    final keysets = keys.map((e) {
      final info = e.asKeysetInfo(mint.mintURL);
      cache[info.id] = info;
      return info;
    }).toList();

    // Fetch keyset state
    if (mint.maxNutsVersion >= 1) {
      final stateResponse = await Nut2.requestKeysetsState(mintURL: mint.mintURL);
      List<KeysetInfo> list = stateResponse.isSuccess ? stateResponse.data : <KeysetInfo>[];
      for (var keysetInfo in list) {
        final info = cache[keysetInfo.id];
        if (info != null) {
          info.active = keysetInfo.active;
          info.inputFeePPK = keysetInfo.inputFeePPK;
        }
      }
    }

    await KeysetStore.addOrReplaceKeysets(keysets);

    return keysets.where((keysetInfo) => keysetInfo.active).toList();
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