
import 'dart:typed_data';

import 'package:pointycastle/pointycastle.dart';

import 'nut_00.dart';

const nutProtocolVersion = 'v1';

String nutURLJoin(String mint, String path) => '$mint/$nutProtocolVersion/$path';

typedef NutsResponse<T> = (
  T data,
  String? errorMsg,
);

typedef BlindedMessageData = (
  /// Blinded messages sent to the mint for signing.
  List<BlindedMessage> blindedMessages,

  /// secrets, kept client side for constructing proofs later.
  List<String> secrets,

  /// Blinding factor used for blinding messages and unblinding signatures after they are received from the mint.
  List<BigInt> rs,

  List<num>? amounts,
);

typedef BlindMessageResult = (
  String B_,
  BigInt r
);

typedef QuoteState = (
  String quote,
  String request,
  bool paid,
  int expiry,
);

