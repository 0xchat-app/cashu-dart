
import 'dart:math';

import 'package:cashu_dart/utils/tools.dart';

import 'nuts/DHKE.dart';
import 'nuts/define.dart';
import 'nuts/nut_00.dart';

class DHKEHelper {

  static BlindedMessageData _createRandomBlindedMessages({
    required String keysetId,
    required List<int> amounts,
  }) {
    List<BlindedMessage> blindedMessages = [];
    List<String> secrets = [];
    List<BigInt> rs = [];

    for (final amount in amounts) {
      final secret = DHKE.randomPrivateKey().asBase64String();
      final (B_, r) = DHKE.blindMessage(secret.asBytes());
      if (B_.isEmpty) continue;

      final blindedMessage = BlindedMessage(
        id: keysetId,
        amount: amount,
        B_: B_,
      );
      blindedMessages.add(blindedMessage);
      secrets.add(secret);
      rs.add(r);
    }

    return (
      blindedMessages,
      secrets,
      rs,
      amounts,
    );
  }

  static BlindedMessageData createBlindedMessages({
    required String keysetId,
    required int amount,
  }) {
    List<int> amounts = splitAmount(amount);
    return _createRandomBlindedMessages(
      keysetId: keysetId,
      amounts: amounts,
    );
  }

  static List<int> splitAmount(int value) {
    if (value == 0) return [];
    List<int> chunks = [];
    for (int i = 0; i < 32; i++) {
      int mask = 1 << i;
      if ((value & mask) != 0) {
        chunks.add(pow(2, i).toInt());
      }
    }
    return chunks;
  }

  static BlindedMessageData createBlankOutputs({
    required String keysetId,
    required int amount,
  }) {
    var count = 1;
    if (amount != 0) {
      count = max(1, (log(amount) / ln2).ceil());
    }
    final amounts = List.generate(count, (index) => 0);
    return _createRandomBlindedMessages(
      keysetId: keysetId,
      amounts: amounts,
    );
  }
}