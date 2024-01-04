
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../model/keyset_info.dart';
import '../../../utils/network/http_client.dart';
import '../../../utils/tools.dart';
import '../define.dart';
import 'nut_01.dart';

class Nut2 {
  static Future<List<KeysetInfo>?> requestKeysetsState({required String mintURL}) async {
    return HTTPClient.get(
      nutURLJoin(mintURL, 'keysets', version: ''),
      modelBuilder: (json) {
        if (json is! Map) return null;
        final keysets = Tools.getValueAs(json, 'keysets', []);
        return keysets.map((e) => KeysetInfo(
          id: e,
          mintURL: mintURL,
          unit: 'sat',
          active: true,
        )).toList();
      },
    );
  }
}