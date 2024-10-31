
import 'dart:convert';

import '../core/nuts/DHKE.dart';
import '../core/nuts/v1/nut_11.dart';
import '../model/cashu_token_info.dart';
import '../utils/tools.dart';

class NutP2PKHelper {
  static CashuTokenP2PKInfo? getInfoWithSecret(String secret) {
    List secretContent;
    try {
      secretContent = jsonDecode(secret);
    } catch (_) {
      return null;
    }

    final p2pkInfo = CashuTokenP2PKInfo(receivePubKeys: []);
    if (secretContent.firstOrNull != 'P2PK' || secretContent.length < 2) return null;

    Map data = secretContent[1] ?? {};

    // pubkey
    final publicKeys = <String>[];
    final pubkey = Tools.getValueAs(data, 'data', '');
    if (pubkey.isNotEmpty) {
      publicKeys.add(pubkey);
    }

    // tags
    final tags = Tools.getValueAs(data, 'tags', []);
    for (final tag in tags) {
      if (tag is! List || tag.length < 2) continue ;

      if (tag.first == P2PKSecretTagKey.pubkeys.name) {
        final value = tag.sublist(1);
        if (value is List<String>) {
          publicKeys.addAll(value);
        }
      } else if (tag.first == P2PKSecretTagKey.refund.name) {
        final value = tag.sublist(1);
        if (value is List<String>) {
          p2pkInfo.refundPubKeys = value;
        }
      } else if (tag.first == P2PKSecretTagKey.lockTime.name) {
        final value = tag[1];
        if (value is String) {
          final timestamp = int.tryParse(value);
          if (timestamp != null) {
            p2pkInfo.lockTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
          }
        }
      } else if (tag.first == P2PKSecretTagKey.nSigs.name) {
        final value = tag[1];
        if (value is String) {
          p2pkInfo.signNumRequired = int.tryParse(value);
        }
      } else if (tag.first == P2PKSecretTagKey.sigflag.name) {
        p2pkInfo.sigFlag = P2PKSecretSigFlag.fromValue(tag[1]);
      }
    }

    p2pkInfo.receivePubKeys = publicKeys;

    return p2pkInfo;
  }

  static P2PKSecret createSecretFromOption(CashuTokenP2PKInfo p2pkOption) {
    final publicKeys = <String>[...p2pkOption.receivePubKeys ?? []];
    assert(publicKeys.isNotEmpty, 'PublicKeys is empty');

    final refundPubKeys = p2pkOption.refundPubKeys;
    final signNumRequired = p2pkOption.signNumRequired;
    final lockTimeTimestamp = p2pkOption.lockTimeTimestamp;
    final sigFlag = p2pkOption.sigFlag;

    final p2pkSecretData = publicKeys.removeAt(0);
    final p2pkSecretTags = [
      if (publicKeys.isNotEmpty) P2PKSecretTagKey.pubkeys.appendValues(publicKeys),
      if (refundPubKeys != null && refundPubKeys.isNotEmpty) P2PKSecretTagKey.refund.appendValues(refundPubKeys),
      if (signNumRequired != null && signNumRequired > 0) P2PKSecretTagKey.nSigs.appendValues(['$signNumRequired']),
      if (lockTimeTimestamp != null) P2PKSecretTagKey.lockTime.appendValues([lockTimeTimestamp]),
      if (sigFlag != null) P2PKSecretTagKey.sigflag.appendValues([sigFlag.value]),
    ];

    return P2PKSecret(
      nonce: DHKE.randomPrivateKey().asBase64String(),
      data: p2pkSecretData,
      tags: p2pkSecretTags,
    );
  }
}