
import 'package:cashu_dart/business/mint/mint_store.dart';
import 'package:cashu_dart/core/keyset_store.dart';
import 'package:cashu_dart/core/nuts/v1/nut_01.dart';
import 'package:cashu_dart/model/mint_model.dart';

import '../../core/nuts/v1/nut_06.dart';
import '../../model/keyset_info.dart';
import 'mint_info_store.dart';

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
    return url.toLowerCase();
  }

  static Future<List<KeysetInfo>> fetchKeysetFromRemote(String mintURL) async {
    final keys = await Nut1.requestKeys(mintURL: mintURL) ?? [];
    final keysets = keys.map((e) => e.asKeysetInfo(mintURL)).toList();
    KeysetStore.addOrReplaceKeysets(keysets);
    return keysets;
  }

  static Future<bool> updateMintInfoFromRemote(IMint mint) async {
    final info = await Nut6.requestMintInfo(mintURL: mint.mintURL);
    if (info == null) return false;

    mint.info = info;
    if (mint.name.isEmpty) {
      mint.name = info.name;
      MintStore.updateMint(mint);
    }
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