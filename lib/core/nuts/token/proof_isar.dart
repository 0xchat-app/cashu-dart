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
    this.witness = '',
    this.dleq,
  });

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

  @Ignore()
  String dleqPlainText = '';

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

  Map<String, dynamic> toV4Json() => {
    'a': int.tryParse(amount) ?? 0,
    's': secret,
    'c': C.hexToBytes(),
    if (witness.isNotEmpty)
      'w': witness
  };

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
    Map<String, dynamic>? dleq;
    if (dleqRaw is Map) {
      dleq = dleqRaw.map((key, value) => MapEntry(key.toString(), value));
    }

    return ProofIsar(
      keysetId: Tools.getValueAs<String>(map, 'id', ''),
      amount: amount,
      secret: Tools.getValueAs<String>(map, 'secret', ''),
      C: Tools.getValueAs<String>(map, 'C', ''),
      witness: witness,
      dleq: dleq,
    );
  }

  factory ProofIsar.fromV4Json(String keysetId, Map json) {
    var amount = '0';
    final amountRaw = json['a'];
    if (amountRaw is int) {
      amount = amountRaw.toString();
    } else if (amountRaw is String) {
      amount = amountRaw;
    }

    var witness = json['w'];
    if (witness is! String) {
      witness = '';
    }

    final dleqRaw = json['d'];
    Map<String, dynamic>? dleq;
    if (dleqRaw is Map) {
      dleq = dleqRaw.map((key, value) => MapEntry(key.toString(), value));
    }

    return ProofIsar(
      keysetId: keysetId,
      amount: amount,
      secret: Tools.getValueAs<String>(json, 's', ''),
      C: Tools.getValueAs<String>(json, 'c', ''),
      witness: witness,
      dleq: dleq,
    );
  }

  static ProofIsar fromMap(Map<String, Object?> map) {
    final dleqPlainText = map['dleqPlainText'];
    Map<String, dynamic>? dleq;
    if (dleqPlainText is String && dleqPlainText.isNotEmpty) {
      try {
        dleq = jsonDecode(dleqPlainText);
      } catch(_) { }
    }

    return ProofIsar(
      keysetId: Tools.getValueAs<String>(map, 'id', ''),
      amount: Tools.getValueAs<String>(map, 'amount', '0'),
      secret: Tools.getValueAs<String>(map, 'secret', ''),
      C: Tools.getValueAs<String>(map, 'C', ''),
      dleq: dleq,
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
        'dleqPlainText': jsonEncode(dleq)
      },
      if (id != null)
        'id': id,
    };
    return ProofIsar.fromMap(newData);
  }

  @override
  String toString() {
    return '${super.toString()}, id: $id, amount: $amount, secret: $secret, C: $C';
  }
}