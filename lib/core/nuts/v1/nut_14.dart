
import 'dart:typed_data';

import 'package:cashu_dart/utils/crypto_utils.dart';
import 'package:cashu_dart/utils/tools.dart';
import 'package:crypto/crypto.dart';

import 'nut_10.dart';

enum HTLCSecretTagKey {

  pubkeys('pubkeys'),
  lockTime('locktime'),
  refund('refund');

  const HTLCSecretTagKey(this.name);
  final String name;

  List<String> appendValues(List<String> values) {
    return [name, ...values];
  }
}

class HTLCSecret with Nut10Secret {
  HTLCSecret({
    required this.data,
    this.tags = const [],
    String? nonce,
  }) {
    this.nonce = nonce ?? this.nonce;

    // tags
    for (final tag in tags) {
      if (tag.length < 2) continue ;

      if (tag.first == HTLCSecretTagKey.pubkeys.name) {
        final value = tag.sublist(1).where((e) => e.isNotEmpty).toList();
        receivePubKeys.addAll(value);
      } else if (tag.first == HTLCSecretTagKey.refund.name) {
        final value = tag.sublist(1);
        refundPubKeys = value;
      } else if (tag.first == HTLCSecretTagKey.lockTime.name) {
        final value = tag[1];
        final timestamp = int.tryParse(value);
        if (timestamp != null) {
          lockTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
        }
      }
    }
  }

  @override
  ConditionType get type => ConditionType.htlc;

  @override
  final String data;

  @override
  final List<List<String>> tags;

  List<String> receivePubKeys = [];
  List<String> refundPubKeys = [];
  DateTime? lockTime;

  // Timestamp in seconds
  String? get lockTimeTimestamp {
    if (lockTime == null) return null;
    return (lockTime!.millisecondsSinceEpoch ~/ 1000).toString();
  }

  static HTLCSecret fromNut10Data(Nut10Data nut10Data) {
    final (_, String nonce, String data, List<List<String>> tags) = nut10Data;
    return HTLCSecret(nonce: nonce, data: data, tags: tags);
  }
}

class HTLCWitness {
  HTLCWitness({
    this.pubkey,
    this.preimage,
  });
  final String? pubkey;
  final String? preimage;
}

class HTLC {
  static (String preimage, String hashString) createHashData([String? preimage]) {
    preimage ??= CryptoUtils.randomPrivateKey().asBase64String();
    final hashBytes = sha256.convert(preimage.asBytes()).bytes;
    final hashString = Uint8List.fromList(hashBytes).asBase64String();
    return (preimage, hashString);
  }
}