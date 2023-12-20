
import 'dart:typed_data';

import 'package:pointycastle/pointycastle.dart';

import 'nut_00.dart';

typedef BlindedMessageData = (
  /// Blinded messages sent to the mint for signing.
  List<BlindedMessage> blindedMessages,

  /// secrets, kept client side for constructing proofs later.
  List<Uint8List> secrets,

  /// Blinding factor used for blinding messages and unblinding signatures after they are received from the mint.
  List<BigInt> rs,

  List<num>? amounts,
);

typedef BlindMessageResult = (
  String B_,
  BigInt r
);