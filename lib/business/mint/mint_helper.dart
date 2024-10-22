
import 'package:cashu_dart/business/proof/keyset_helper.dart';
import 'package:cashu_dart/utils/list_extension.dart';
import 'package:flutter/foundation.dart';

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
      debugPrint('[E][Cashu - getMintURL] mintURL must starts with https');
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

  static Future updateMintKeysetFromRemote(IMint mint) async {
    final keysets = await fetchKeysetFromRemote(mint);
    if (keysets.isEmpty) return ;

    mint.cleanKeysetId();
    _updateMintKeyset(mint, keysets);
  }

  static Future updateMintKeysetFromLocal(IMint mint) async {
    final keysets = await KeysetStore.getKeyset(mintURL: mint.mintURL);
    if (keysets.isEmpty) return ;

    _updateMintKeyset(mint, keysets);
  }

  static void _updateMintKeyset(IMint mint, List<KeysetInfo> keysets) {
    if (keysets.isEmpty) return ;
    final newKeysets = keysets
        .groupBy((item) => item.unit)
        .entries.map((map) {
      final target = KeysetHelper.findBetterKeyset(map.value);
      return MapEntry(map.key, target);
    })
        .expand((map) => [map.value])
        .nonNulls;
    for (var keyset in newKeysets) {
      mint.updateKeysetId(keyset.id, keyset.unit);
    }
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