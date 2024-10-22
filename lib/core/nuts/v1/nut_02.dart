
import 'dart:convert';
import 'dart:typed_data';

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
    List<int> pubkeysConcat = [];
    for (var entry in sortedKeys) {
      pubkeysConcat.addAll(entry.value.hexToBytes());
    }

    // HASH_SHA256 the concatenated public keys
    final hash = sha256.convert(pubkeysConcat);

    // take the first 14 characters of the hex-encoded hash
    final hexEncoded = Uint8List.fromList(hash.bytes).asHex().substring(0, 14);

    // prefix it with a keyset ID version byte
    return '00$hexEncoded';
  }

  @Deprecated('DEPRECATED 0.15.0')
  static String deriveKeySetIdDeprecated(MintKeys keys) {

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

    // take the first 12 characters of the hex-encoded hash
    return Uint8List.fromList(hash.bytes).asBase64String().substring(0, 12);
  }

  static bool isHexKeysetId(String keysetId) {
    if (keysetId.length != 16) return false;
    try {
      keysetId.hexToBytes();
      return true;
    } catch (_) {
      return false;
    }
  }
}