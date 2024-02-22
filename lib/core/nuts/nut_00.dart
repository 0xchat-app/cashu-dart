
import 'dart:convert';

import '../../utils/database/db.dart';
import '../../utils/database/db_object.dart';
import '../../utils/tools.dart';

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
      print('[Error][Nut1 - getDecodedToken] encodeBase64ToJson failed.');
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
          token: proofs.map((e) => TokenEntry.fromJson(e)).toList(),
          memo: mints.firstOrNull?['url'] ?? '',
        );
      }
    }

    // check if v1
    if (obj is List) {
      return Token(
        token: obj.map((e) => TokenEntry.fromJson(e)).toList(),
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
  });

  final String id;
  final String amount;
  final String C_;

  factory BlindedSignature.fromServerMap(Map json) {
    final amount = json['amount'] as num;
    return BlindedSignature(
      id: Tools.getValueAs<String>(json, 'id', ''),
      amount: BigInt.from(amount).toString(),
      C_: Tools.getValueAs<String>(json, 'C_', ''),
    );
  }

  Map<String, String> toJson() => {
    'id': id,
    'amount': amount,
    'C_': C_,
  };

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

  int get amountNum => int.tryParse(amount) ?? 0;

  @override
  Map<String, Object?> toMap() => {
    'id': id,
    'amount': amount,
    'secret': secret,
    'C': C,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': int.tryParse(amount) ?? 0,
    'secret': secret,
    'C': C,
    if (witness.isNotEmpty)
      'witness': witness
  };

  static Proof fromMap(Map<String, Object?> map) {
    var amount = '0';
    final amountRaw = map['amount'];
    if (amountRaw is int) {
      amount = amountRaw.toString();
    } else if (amountRaw is String) {
      amount = amountRaw;
    }
    return Proof(
      id: Tools.getValueAs<String>(map, 'id', ''),
      amount: amount,
      secret: Tools.getValueAs<String>(map, 'secret', ''),
      C: Tools.getValueAs<String>(map, 'C', ''),
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
    return ['witness'];
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
    this.token = const [],
    this.memo = '',
    this.unit = '',
  });

  /// token entries
  final List<TokenEntry> token;

  /// a message to send along with the token
  final String memo;

  final String unit;

  BigInt get sumProofsValue => token.fold(BigInt.zero, (pre, entry) => pre + entry.sumProofsValue);

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
      token: token,
      memo: json['memo']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'sat',
    );
  }

  Map toJson() => {
    'token': token.map((e) => e.toJson()).toList(),
    'memo': memo,
    'unit': unit,
  };

  @override
  String toString() {
    return '${super.toString()}, memo: $memo, unit: $unit, token: $token';
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
          return Proof.fromMap(e);
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