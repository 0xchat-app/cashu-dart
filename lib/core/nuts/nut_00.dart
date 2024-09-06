
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../utils/database/db.dart';
import '../../utils/database/db_object.dart';
import '../../utils/tools.dart';
import '../DHKE_helper.dart';

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

@reflector
class Proof extends DBObject {
  Proof({
    required this.id,
    required this.amount,
    required this.secret,
    required this.C,
    this.witness = '',
    this.dleq,
  });

  /// Keyset id, used to link proofs to a mint an its MintKeys.
  final String id;

  /// Amount denominated in Satoshis. Has to match the amount of the mints signing key.
  final String amount;

  /// The initial secret that was (randomly) chosen for the creation of this proof.
  final String secret;

  /// The unblinded signature for this secret, signed by the mints private key.
  final String C;

  String witness;

  String dleqPlainText = '';

  Map<String, dynamic>? dleq;

  int get amountNum => int.tryParse(amount) ?? 0;

  /// Y: hash_to_curve(secret)
  String get Y => DHKEHelper.hashToCurve(secret);

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': int.tryParse(amount) ?? 0,
    'secret': secret,
    'C': C,
    if (witness.isNotEmpty)
      'witness': witness
  };

  static Proof fromServerJson(Map<String, Object?> map) {
    var amount = '0';
    final amountRaw = map['amount'];
    if (amountRaw is int) {
      amount = amountRaw.toString();
    } else if (amountRaw is String) {
      amount = amountRaw;
    }

    var witness = map['witness'];
    if (witness is! String) {
      witness = '';
    }

    final dleqRaw = map['dleq'];
    Map<String, dynamic>? dleq;
    if (dleqRaw is Map) {
      dleq = dleqRaw.map((key, value) => MapEntry(key.toString(), value));
    }

    return Proof(
      id: Tools.getValueAs<String>(map, 'id', ''),
      amount: amount,
      secret: Tools.getValueAs<String>(map, 'secret', ''),
      C: Tools.getValueAs<String>(map, 'C', ''),
      witness: witness,
      dleq: dleq,
    );
  }

  @override
  Map<String, Object?> toMap() => {
    'id': id,
    'amount': amount,
    'secret': secret,
    'C': C,
    'dleqPlainText': jsonEncode(dleq)
  };

  static Proof fromMap(Map<String, Object?> map) {

    final dleqPlainText = map['dleqPlainText'];
    Map<String, dynamic>? dleq;
    if (dleqPlainText is String && dleqPlainText.isNotEmpty) {
      try {
        dleq = jsonDecode(dleqPlainText);
      } catch(_) { }
    }

    return Proof(
      id: Tools.getValueAs<String>(map, 'id', ''),
      amount: Tools.getValueAs<String>(map, 'amount', '0'),
      secret: Tools.getValueAs<String>(map, 'secret', ''),
      C: Tools.getValueAs<String>(map, 'C', ''),
      dleq: dleq,
    );
  }

  static String? tableName() {
    return "Proof";
  }

  //primaryKey
  static List<String?> primaryKey() {
    return ['id', 'secret'];
  }

  //ignoreKey
  static List<String?> ignoreKey() {
    return ['witness', 'dleq'];
  }

  static Map<String, String?> updateTable() {
    return {
      "3": '''alter table ${tableName()} add dleqPlainText TEXT DEFAULT "";'''
    };
  }

  @override
  String toString() {
    return '${super.toString()}, id: $id, amount: $amount, secret: $secret, C: $C';
  }
}

extension ProofListEx on List<Proof> {
  int get totalAmount => fold(0, (pre, proof) => pre + proof.amountNum);
}

class Token {
  Token({
    this.entries = const [],
    this.memo = '',
    this.unit = '',
  });

  /// token entries
  final List<TokenEntry> entries;

  /// a message to send along with the token
  final String memo;

  final String unit;

  BigInt get sumProofsValue => entries.fold(BigInt.zero, (pre, entry) => pre + entry.sumProofsValue);

  factory Token.fromJson(Map json) {
    final tokenJson = json['token'] ?? [];
    List<TokenEntry> token = [];
    if (tokenJson is List) {
      token = tokenJson.map((e) {
        if (e is Map<String, Object?>) {
          return TokenEntry.fromJson(e);
        }
        return null;
      }).where((element) => element != null).cast<TokenEntry>().toList();
    }
    return Token(
      entries: token,
      memo: json['memo']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'sat',
    );
  }

  Map toJson() => {
    'token': entries.map((e) => e.toJson()).toList(),
    'memo': memo,
    'unit': unit,
  };

  @override
  String toString() {
    return '${super.toString()}, memo: $memo, unit: $unit, token: $entries';
  }
}

class TokenEntry {
  TokenEntry({
    this.proofs = const [],
    this.mint = '',
  });

  /// list of proofs
  final List<Proof> proofs;

  /// the mints URL
  final String mint;

  BigInt get sumProofsValue => proofs.fold(
      BigInt.zero, (pre, proof) => pre + proof.amount.asBigInt()
  );

  factory TokenEntry.fromJson(Map json) {
    final proofsJson = json['proofs'] ?? [];
    List<Proof> proofs = [];
    if (proofsJson is List) {
      proofs = proofsJson.map((e) {
        if (e is Map<String, Object?>) {
          return Proof.fromServerJson(e);
        }
        return null;
      }).where((element) => element != null).cast<Proof>().toList();
    }
    return TokenEntry(
      proofs: proofs,
      mint: json['mint'] ?? '',
    );
  }

  Map toJson() => {
    'proofs': proofs.map((e) => e.toJson()).toList(),
    'mint': mint,
  };

  @override
  String toString() {
    return '${super.toString()}, mint: $mint, proofs: $proofs';
  }
}