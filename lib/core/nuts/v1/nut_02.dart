
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../model/keyset_info.dart';
import '../../../utils/network/http_client.dart';
import '../../../utils/tools.dart';
import '../define.dart';

class Nut2 {
  static Future<CashuResponse<List<KeysetInfo>>> requestKeysetsState({required String mintURL}) async {
    return HTTPClient.get(
      nutURLJoin(mintURL, 'keysets'),
      modelBuilder: (json) {
        if (json is! Map) return null;
        final keysets = Tools.getValueAs(json, 'keysets', []);
        return keysets.map((e) => KeysetInfo.fromServerMap(e, mintURL)).toList();
      },
    );
  }

  /*
  1 - sort public keys by their amount in ascending order
  2 - concatenate all public keys to one byte array
  3 - HASH_SHA256 the concatenated public keys
  4 - take the first 14 characters of the hex-encoded hash
  5 - prefix it with a keyset ID version byte(currently used version byte is 00)
  */
  static String deriveKeySetId(MintKeys keys) {

    // sort public keys by their amount in ascending order
    final sortedKeys = keys.entries.toList()..sort((a, b) {
      final aNum = BigInt.tryParse(a.key) ?? BigInt.zero;
      final bNum = BigInt.tryParse(b.key) ?? BigInt.zero;
      return aNum.compareTo(bNum);
    });

    // concatenate all (sorted) public keys to one string
    final pubKeysConcat = sortedKeys.map((entry) => entry.value).join('');

    // HASH_SHA256 the concatenated public keys
    final bytes = utf8.encode(pubKeysConcat);
    final hash = sha256.convert(bytes);

    // take the first 14 characters of the hex-encoded hash
    final hexEncoded = base64.encode(hash.bytes).substring(0, 14);

    // prefix it with a keyset ID version byte
    return '00$hexEncoded';
  }
}