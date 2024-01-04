

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../utils/network/http_client.dart';
import '../../../utils/tools.dart';
import '../define.dart';

typedef MintKeys = Map<String, String>;

class MintKeysPayload {
  MintKeysPayload(this.id, this.unit, this.keys);
  final String id;
  final String unit;
  final MintKeys keys;

  static MintKeysPayload? fromServerMap(json) {
    final id = Tools.getValueAs(json, 'id', '');
    final unit = Tools.getValueAs(json, 'unit', '');
    final keys = Tools.getValueAs<Map>(json, 'keys', {})
        .map((key, value) => MapEntry(key.toString(), value.toString()));
    if (id.isEmpty || unit.isEmpty || keys.isEmpty) return null;
    return MintKeysPayload(id, unit, keys);
  }

  @override
  String toString() {
    return '${super.toString()}, id: $id, unit: $unit';
  }
}

class Nut1 {
  static Future<List<MintKeysPayload>?> requestKeys({required String mintURL, String? keysetId}) async {
    var endpoint = nutURLJoin(mintURL, 'keys', version: '');
    if (keysetId != null) {
      keysetId = Uri.encodeComponent(keysetId);
      endpoint = '$endpoint/$keysetId';
    }
    return HTTPClient.get(
      endpoint,
      modelBuilder: (json) {
        if (json is! Map) return null;
        final keys = Tools.getValueAs<Map>(json, 'keys', {})
            .map((key, value) => MapEntry(key.toString(), value.toString()));
        return [MintKeysPayload(keysetId ?? keys.deriveKeysetId(), 'sat', keys)];
      },
    );
  }
}

extension _MintKeysEx on MintKeys {
  String deriveKeysetId() {
    final keys = entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final pubkeysConcat = keys.map((entry) => entry.value).join('');

    var bytes = utf8.encode(pubkeysConcat);
    var hash = sha256.convert(bytes);

    return base64.encode(hash.bytes).substring(0, 12);
  }
}