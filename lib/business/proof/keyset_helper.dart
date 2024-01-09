
import '../../core/keyset_store.dart';
import '../../core/nuts/define.dart';
import '../../model/keyset_info.dart';
import '../../model/mint_model.dart';
import '../mint/mint_helper.dart';

class KeysetHelper {

  /// Obtain the keyset of mint corresponding to the unit.
  /// If the local data is not available, obtain it from the remote endpoint
  static Future<KeysetInfo?> tryGetMintKeysetInfo(IMint mint, String unit, [String? keysetId]) async {
    keysetId ??= mint.keysetId(unit);
    // from local
    final keysets = await KeysetStore.getKeyset(mintURL: mint.mintURL, id: keysetId, unit: unit);
    var keysetInfo = keysets.firstOrNull;

    if (keysetInfo == null || keysetInfo.keyset.isEmpty) {
      // from remote
      final newKeysets = await MintHelper.fetchKeysetFromRemote(mint.mintURL, keysetId);
      keysetInfo = newKeysets.where((element) => element.unit == unit).firstOrNull;
    }
    if (keysetInfo == null) return null;

    // update mint keysetId
    if (keysetInfo.keyset.isNotEmpty) {
      mint.updateKeysetId(keysetInfo.id, unit);
    }

    return keysetInfo;
  }

  static Future<MintKeys?> keysetFetcher(IMint mint, String unit, String keysetId) async {
    final info = await tryGetMintKeysetInfo(mint, unit, keysetId);
    if (info?.keyset.isEmpty ?? true) return null;
    return info?.keyset;
  }

}