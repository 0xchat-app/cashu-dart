import 'package:cashu_dart/utils/tools.dart';

import 'proof.dart';

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