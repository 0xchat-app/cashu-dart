
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../utils/tools.dart';
import 'token/proof.dart';
import 'token/token_model.dart';

class Nut0 {
  static const tokenPrefix = 'cashu';
  static const tokenVersion = 'A';

  // Support version prefixes
  static const List<String> uriPrefixes = ['web+cashu://', 'cashu://', 'cashu:', 'cashuA'];

  static String encodedToken(Token token) {
    String json = jsonEncode(token.toJson());
    String base64Encoded = base64.encode(utf8.encode(json));
    return tokenPrefix + tokenVersion + base64Encoded;
  }

  static Token? decodedToken(String token) {
    bool flag = false;
    for (var prefix in uriPrefixes) {
      if (token.startsWith(prefix)) {
        token = token.substring(prefix.length);
        flag = true;
        break;
      }
    }

    if (!flag) return null;

    dynamic obj;
    try {
      obj = token.encodeBase64ToJson<Map>();
    } catch(e) {
      debugPrint('[Error][Nut1 - getDecodedToken] encodeBase64ToJson failed, object: $token');
      return null;
    }

    if (obj == null) return null;

    // check if v3
    if (obj is Map && obj.containsKey('token')) {
      return Token.fromJson(obj);
    }

    // if v2 token return v3 format
    if (obj is Map && obj.containsKey('proofs')) {
      final proofs = obj['proofs'];
      final mints = obj['mints'];
      if (proofs is List && mints is List) {
        return Token(
          entries: proofs.map((e) => TokenEntry.fromJson(e)).toList(),
          memo: mints.firstOrNull?['url'] ?? '',
        );
      }
    }

    // check if v1
    if (obj is List) {
      return Token(
        entries: obj.map((e) => TokenEntry.fromJson(e)).toList(),
      );
    }

    return null;
  }
}

class BlindedMessage {
  BlindedMessage({
    required this.id,
    required this.amount,
    required this.B_,
  });

  final String id;
  final num amount;
  final String B_;

  @override
  String toString() {
    return '${super.toString()}, id: $id, amount: $amount, B_: $B_';
  }
}

class BlindedSignature {
  BlindedSignature({
    required this.id,
    required this.amount,
    required this.C_,
    this.dleq,
  });

  final String id;
  final String amount;
  final String C_;
  final Map? dleq;

  factory BlindedSignature.fromServerMap(Map json) {
    final amount = json['amount'] as num;
    return BlindedSignature(
      id: Tools.getValueAs<String>(json, 'id', ''),
      amount: BigInt.from(amount).toString(),
      C_: Tools.getValueAs<String>(json, 'C_', ''),
      dleq: Tools.getValueAs<Map?>(json, 'dleq', null),
    );
  }

  @override
  String toString() {
    return '${super.toString()}, id: $id, amount: $amount, C_: $C_';
  }
}

extension ProofListEx on List<Proof> {
  int get totalAmount => fold(0, (pre, proof) => pre + proof.amountNum);
}
