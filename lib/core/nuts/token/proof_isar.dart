import 'dart:convert';

import 'package:isar/isar.dart';

import '../../../utils/tools.dart';
import '../../DHKE_helper.dart';

part 'proof_isar.g.dart';

@collection
class ProofIsar {
  ProofIsar({
    required this.keysetId,
    required this.amount,
    required this.secret,
    required this.C,
    required this.dleqPlainText,
    this.witness = '',
  }) : dleq = dleqFromRaw(dleqPlainText);

  Id id = Isar.autoIncrement;

  /// Keyset id, used to link proofs to a mint an its MintKeys.
  final String keysetId;

  /// Amount denominated in Satoshis. Has to match the amount of the mints signing key.
  final String amount;

  /// The initial secret that was (randomly) chosen for the creation of this proof.
  @Index(composite: [CompositeIndex('keysetId')], unique: true)
  final String secret;

  /// The unblinded signature for this secret, signed by the mints private key.
  final String C;

  @Ignore()
  String witness;

  final String dleqPlainText;

  @Ignore()
  Map<String, dynamic>? dleq;

  @ignore
  int get amountNum => int.tryParse(amount) ?? 0;

  /// Y: hash_to_curve(secret)
  @ignore
  String get Y => DHKEHelper.hashToCurve(secret);

  Map<String, dynamic> toJson() => {
    'id': keysetId,
    'amount': int.tryParse(amount) ?? 0,
    'secret': secret,
    'C': C,
    if (witness.isNotEmpty)
      'witness': witness
  };

  Map<String, dynamic> toV4Json() {
    // dleq
    final e = dleq?['e'];
    final s = dleq?['s'];
    final r = dleq?['r'];

    final dleqMap = {
      if (e is String && e.isNotEmpty)
        'e': e.hexToBytes(),
      if (s is String && s.isNotEmpty)
        's': s.hexToBytes(),
      if (r is String && r.isNotEmpty)
        'r': r.hexToBytes(),
    };

    return {
      'a': int.tryParse(amount) ?? 0,
      's': secret,
      'c': C.hexToBytes(),
      if (witness.isNotEmpty)
        'w': witness,
      if (dleqMap.keys.length == 3)
        'd': dleqMap,
    };
  }

  static ProofIsar fromServerJson(Map<String, Object?> map) {
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
    var dleqPlainText = '';
    try {
      dleqPlainText = json.encode(dleqRaw);
    } catch (_) {}

    return ProofIsar(
      keysetId: Tools.getValueAs<String>(map, 'id', ''),
      amount: amount,
      secret: Tools.getValueAs<String>(map, 'secret', ''),
      C: Tools.getValueAs<String>(map, 'C', ''),
      witness: witness,
      dleqPlainText: dleqPlainText,
    );
  }

  factory ProofIsar.fromV4Json(String keysetId, Map map) {
    var amount = '0';
    final amountRaw = map['a'];
    if (amountRaw is int) {
      amount = amountRaw.toString();
    } else if (amountRaw is String) {
      amount = amountRaw;
    }

    var witness = map['w'];
    if (witness is! String) {
      witness = '';
    }

    final dleqRaw = map['d'];
    var dleqPlainText = '';
    try {
      dleqPlainText = json.encode(dleqRaw);
    } catch (_) {}

    return ProofIsar(
      keysetId: keysetId,
      amount: amount,
      secret: Tools.getValueAs<String>(map, 's', ''),
      C: Tools.getValueAs<String>(map, 'c', ''),
      witness: witness,
      dleqPlainText: dleqPlainText,
    );
  }

  static ProofIsar fromMap(Map<String, Object?> map) {
    return ProofIsar(
      keysetId: Tools.getValueAs<String>(map, 'id', ''),
      amount: Tools.getValueAs<String>(map, 'amount', '0'),
      secret: Tools.getValueAs<String>(map, 'secret', ''),
      C: Tools.getValueAs<String>(map, 'C', ''),
      dleqPlainText: Tools.getValueAs<String>(map, 'dleqPlainText', ''),
    );
  }

  ProofIsar copyWith({
    String? id,
  }) {
    final newData = {
      ...{
        'id': id,
        'amount': amount,
        'secret': secret,
        'C': C,
        'dleqPlainText': dleqPlainText
      },
      if (id != null)
        'id': id,
    };
    return ProofIsar.fromMap(newData);
  }

  static Map<String, dynamic> dleqFromRaw(String dleqPlainText) {
    try {
      final decoded = json.decode(dleqPlainText) as Map;
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      return {};
    }
  }

  @override
  String toString() {
    return '${super.toString()}, id: $id, amount: $amount, secret: $secret, C: $C, dleq: $dleq';
  }
}