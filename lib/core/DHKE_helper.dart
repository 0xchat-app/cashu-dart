
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cashu_dart/utils/tools.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

import 'nuts/DHKE.dart';
import 'nuts/define.dart';
import 'nuts/nut_00.dart';

class DHKEHelper {

  static BlindedMessageData _createBlindedMessages({
    required String keysetId,
    required List<int> amounts,
    List<String>? secrets,
  }) {

    if (secrets != null && secrets.length != amounts.length) return ([],[],[],[]);

    List<BlindedMessage> blindedMessages = [];
    List<String> pSecrets = [];
    List<BigInt> rs = [];

    for (var i = 0; i < amounts.length; i++) {
      final amount = amounts[i];
      final secret = secrets != null ? secrets[i] : DHKE.randomPrivateKey().asBase64String();
      final (B_, r) = DHKE.blindMessage(secret.asBytes());
      if (B_.isEmpty) continue;

      final blindedMessage = BlindedMessage(
        id: keysetId,
        amount: amount,
        B_: B_,
      );
      blindedMessages.add(blindedMessage);
      pSecrets.add(secret);
      rs.add(r);
    }

    return (
      blindedMessages,
      pSecrets,
      rs,
      amounts,
    );
  }

  static BlindedMessageData createBlindedMessages({
    required String keysetId,
    required int amount,
  }) {
    List<int> amounts = splitAmount(amount);
    return _createBlindedMessages(
      keysetId: keysetId,
      amounts: amounts,
    );
  }

  static BlindedMessageData createBlindedMessagesWithSecret({
    required String keysetId,
    required List<int> amounts,
    required List<String> secrets,
  }) {
    return _createBlindedMessages(
      keysetId: keysetId,
      amounts: amounts,
      secrets: secrets,
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
    return _createBlindedMessages(
      keysetId: keysetId,
      amounts: amounts,
    );
  }

  static Uint8List get domainSeparator => 'Secp256k1_HashToCurve_Cashu_'.asBytes();

  static String hashToCurve(String message) {

    Uint8List messageBytes = message.asBytes();
    Uint8List msgToHash = Uint8List.fromList(
      sha256
          .convert([...domainSeparator, ...messageBytes])
          .bytes,
    );

    int counter = 0;
    while (counter < 1 << 16) {
      Uint8List hash = Uint8List.fromList(
        sha256.convert([...msgToHash, ...byteBufferFromInt(counter)]).bytes,
      );
      try {
        // will error if point does not lie on curve
        final point = DHKE.pointFromHex('02${hash.asHex()}');
        return DHKE.ecPointToHex(point);
      } catch (e) {
        counter++;
      }
    }
    throw Exception("No valid point found");
  }

  static Uint8List byteBufferFromInt(int value) {
    var buffer = Uint8List(4);
    ByteData.view(buffer.buffer).setUint32(0, value, Endian.little);
    return buffer;
  }
}