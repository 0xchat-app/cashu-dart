
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../utils/network/http_client.dart';
import 'nut_01.dart';

class Nut2 {
  /// Get the mints keysets in no specific order
  /// Returns all the mints past and current keysets.
  static Future<List<String>?> supportKeySetsId({required String mintURL}) async {
    return HTTPClient.get(
      '$mintURL/keysets',
      modelBuilder: (json) {
        if (json is Map) {
          final keysets = json['keysets'];
          if (keysets is List) {
            return keysets.map((e) => e.toString()).toList();
          }
        }
        return null;
      },
    );
  }

  static String deriveKeysetId(MintKeys keys) {

    // sort keyset by amount
    final sortedKeys = keys.entries.toList()..sort((a, b) {
      final aNum = BigInt.tryParse(a.key) ?? BigInt.zero;
      final bNum = BigInt.tryParse(b.key) ?? BigInt.zero;
      return aNum.compareTo(bNum);
    });

    // concatenate all (sorted) public keys to one string
    final pubkeysConcat = sortedKeys.map((entry) => entry.value).join('');

    // HASH_SHA256 the concatenated public keys
    final bytes = utf8.encode(pubkeysConcat);
    final hash = sha256.convert(bytes);

    // take the first 12 characters of the hash
    final result = base64.encode(hash.bytes).substring(0, 12);

    return result;
  }
}