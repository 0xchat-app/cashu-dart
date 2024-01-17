

import '../../api/cashu_api.dart';
import '../../core/keyset_store.dart';
import '../../core/nuts/define.dart';
import '../../core/nuts/v0/nut.dart' as v0;
import '../../core/nuts/v1/nut.dart' as v1;
import '../../model/keyset_info.dart';
import '../../model/mint_info.dart';
import '../../model/mint_model.dart';
import '../../utils/network/response.dart';
import 'mint_info_store.dart';
import 'mint_store.dart';

typedef RequestKeysAction = Future<CashuResponse<List<MintKeysPayload>>> Function({
  required String mintURL,
  String? keysetId,
});

typedef RequestMintInfoAction = Future<CashuResponse<MintInfo>> Function({
  required String mintURL,
});

class MintHelper {

  static RequestKeysAction get requestKeys => Cashu.isV1
      ? v1.Nut1.requestKeys
      : v0.Nut1.requestKeys;

  static RequestMintInfoAction get requestMintInfo => Cashu.isV1
      ? v1.Nut6.requestMintInfo
      : v0.Nut9.requestMintInfo;

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

  static Future<List<KeysetInfo>> fetchKeysetFromRemote(String mintURL, [String? keysetId]) async {
    final response = await requestKeys(mintURL: mintURL, keysetId: keysetId);
    final keys = response.isSuccess ? response.data : <MintKeysPayload>[];
    final keysets = keys.map((e) => e.asKeysetInfo(mintURL)).toList();
    KeysetStore.addOrReplaceKeysets(keysets);
    return keysets;
  }

  static Future<bool> updateMintInfoFromRemote(IMint mint) async {
    final response = await requestMintInfo(mintURL: mint.mintURL);
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
    final url = mint.mintURL;
    final keysets = await fetchKeysetFromRemote(url);
    if (keysets.isEmpty) return ;

    mint.cleanKeysetId();
    keysets.forEach((keyset) {
      mint.updateKeysetId(keyset.id, keyset.unit);
    });
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