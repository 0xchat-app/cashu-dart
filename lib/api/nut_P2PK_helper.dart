
import 'dart:convert';

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

    final p2pkInfo = CashuTokenP2PKInfo();
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
        publicKeys.addAll(tag.sublist(1).cast<String>());
      } else if (tag.first == P2PKSecretTagKey.refund.name) {
        p2pkInfo.refundPubKeys = tag.sublist(1).cast<String>();
      } else if (tag.first == P2PKSecretTagKey.lockTime.name) {
        p2pkInfo.lockTime = tag[1];
      } else if (tag.first == P2PKSecretTagKey.nSigs.name) {
        p2pkInfo.signNumRequired = tag[1];
      } else if (tag.first == P2PKSecretTagKey.sigflag.name) {
        p2pkInfo.sigFlag = P2PKSecretSigFlag.fromValue(tag[1]);
      }
    }

    if (publicKeys.isNotEmpty) {
      p2pkInfo.receivePubKeys = publicKeys;
    }

    return p2pkInfo;
  }
}