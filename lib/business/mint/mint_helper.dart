

import '../../core/keyset_store.dart';
import '../../core/mint_actions.dart';
import '../../core/nuts/define.dart';
import '../../core/nuts/v1/nut.dart' as v1;
import '../../model/keyset_info.dart';
import '../../model/mint_model.dart';
import 'mint_info_store.dart';
import 'mint_store.dart';

class MintHelper {

  static String getMintURL(String url) {
    url = url.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      print('[E][Cashu - getMintURL] mintURL must starts with https');
      url = 'https://$url';
    }

    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  static Future<List<KeysetInfo>> fetchKeysetFromRemote(IMint mint, [String? keysetId]) async {
    final response = await mint.requestKeysAction(mintURL: mint.mintURL, keysetId: keysetId);
    final keys = response.isSuccess ? response.data : <MintKeysPayload>[];
    final keysets = keys.map((e) => e.asKeysetInfo(mint.mintURL)).toList();
    KeysetStore.addOrReplaceKeysets(keysets);
    return keysets;
  }

  static Future<bool> updateMintInfoFromRemote(IMint mint) async {
    final response = await mint.requestMintInfoAction(mintURL: mint.mintURL);
    if (!response.isSuccess) return false;
    final info = response.data;
    mint.info = info;
    if (mint.name.isEmpty) {
      mint.name = info.name;
    }
    MintStore.updateMint(mint);
    MintInfoStore.addMintInfo(info);
    return true;
  }

  static updateMintKeysetFromRemote(IMint mint) async {
    final keysets = await fetchKeysetFromRemote(mint);
    if (keysets.isEmpty) return ;

    mint.cleanKeysetId();
    for (var keyset in keysets) {
      mint.updateKeysetId(keyset.id, keyset.unit);
    }
    KeysetStore.addOrReplaceKeysets(keysets);
  }

  static Future<KeysetInfo?> tryGetMintKeyset(IMint mint, String keysetId, [String unit = 'sat']) async {
    // Local
    final result = await KeysetStore.getKeyset(
      mintURL: mint.mintURL,
      id: keysetId,
      unit: unit,
    );
    final keysetInfo = result.lastOrNull;
    if (keysetInfo != null && keysetInfo.keyset.isNotEmpty) return keysetInfo;

    // Remote
    mint.keysetId(unit);
    return null;
  }

  static Future<int> getMaxNutsVersion(String mintURL) async {
    final response = await v1.Nut6.requestMintInfo(mintURL: mintURL);
    if (response.isSuccess) return 1;
    return 0;
  }
}

extension MintKeysPayloadEx on MintKeysPayload {
  KeysetInfo asKeysetInfo(String mintURL) =>
      KeysetInfo(
        id: id,
        mintURL: mintURL,
        unit: unit,
        active: true,
        keyset: keys,
      );
}