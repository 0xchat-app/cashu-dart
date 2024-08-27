import 'dart:math';
import 'dart:typed_data';
import 'package:cashu_dart/utils/tools.dart';
import 'package:pointycastle/export.dart';

import '../../model/unblinding_data.dart';
import 'define.dart';
import 'nut_00.dart';

/*
  Bob (mint)
  [k] private key of mint (one for each amount)
  [K] public key of mint
  [Q] promise (blinded signature)

  Alice (user)
  [x] random string (secret message), corresponds to point Y on curve
  [r] private key (blinding factor)
  [T] blinded message
  [Z] proof (unblinded signature)

  Blind Diffie-Hellmann key exchange (BDHKE)
  Mint Bob publishes public key K = kG
  Alice picks secret x and computes Y = hash_to_curve(x)
  Alice sends to Bob: B_ = Y + rG with r being a random blinding factor (blinding)
  Bob sends back to Alice blinded key: C_ = kB_ (these two steps are the DH key exchange) (signing)
  Alice can calculate the unblinded key as C_ - rK = kY + krG - krG = kY = C (unblinding)
  Alice can take the pair (x, C) as a token and can send it to Carol.
  Carol can send (x, C) to Bob who then checks that k*hash_to_curve(x) == C (verification), and if so treats it as a valid spend of a token, adding x to the list of spent secrets.
*/

class DHKE {

  static Uint8List randomPrivateKey() {
    var random = FortunaRandom();
    var randomSeed = Random.secure();
    List<int> seeds = List<int>.generate(32, (_) => randomSeed.nextInt(256));
    random.seed(KeyParameter(Uint8List.fromList(seeds)));

    return random.nextBytes(32);
  }

  static ECPoint hashToCurve(Uint8List secret) {
    ECPoint? point;
    var digest = SHA256Digest();

    while (point == null) {
      Uint8List hash = digest.process(secret);
      String hashHex = hash.asHex();
      String pointXHex = '02$hashHex';

      try {
        point = pointFromHex(pointXHex);
      } catch (error) {
        secret = digest.process(secret);
      }
    }
    return point;
  }

  // blinding: B_ = Y + rG
  static BlindMessageResult blindMessage(Uint8List secret, [BigInt? r]) {

    var Y = hashToCurve(secret);

    // Random r
    r ??= randomPrivateKey().asBigInt();

    // Calculate the point rG
    final domainParams = ECCurve_secp256k1();
    final G = domainParams.G;
    final rG = G * r;
    final B_ = Y + rG;

    final bStr = B_ != null ? DHKE.ecPointToHex(B_) : '';
    return (bStr, r);
  }

  static BigInt generateRandomBigInt() {
    var rnd = Random.secure();
    var bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    return BigInt.parse(Uint8List.fromList(bytes).asHex(), radix: 16);
  }

  // unblinding: C_ - rK = kY + krG - krG = kY = C
  static ECPoint? unblindingSignature(String cHex, BigInt r, String kHex) {
    final C_ = pointFromHex(cHex);
    final rK = pointFromHex(kHex) * r;
    if (rK == null) return null;
    return C_ - rK;
  }

  static Future<List<Proof>?> constructProofs({
    required List<UnblindingData> data,
    required Future<MintKeys?> Function(String mintURL, String unit, String keysetId,) keysFetcher,
  }) async {
    final List<Proof> proofs = [];
    for (int i = 0; i < data.length; i++) {
      final unblindingData = data[i];
      final promise = unblindingData.signature;
      final secret = unblindingData.secret;
      final keysetId = promise.id;
      final keys = await keysFetcher(unblindingData.mintURL, unblindingData.unit, keysetId,);
      if (keys == null) return null;

      final r = unblindingData.r.asBigInt();
      final K = keys[promise.amount];
      if (K == null || r == BigInt.zero) {
        throw Exception('[E][Cashu - constructProofs] key not found.');
      }
      
      final dleq = promise.dleq?.map((key, value) => MapEntry(key.toString(), value));
      if (dleq != null && dleq.isNotEmpty) {
        dleq['r'] = r.toString();
      }

      final C = unblindingSignature(promise.C_, r, K);
      if (C == null) return null;
      final unblindingProof = Proof(
        id: promise.id,
        amount: promise.amount,
        secret: secret,
        C: ecPointToHex(C),
        dleq: dleq,
      );
      proofs.add(unblindingProof);
    }

    if (proofs.length != data.length) return null;

    return proofs;
  }

  static String ecPointToHex(ECPoint point, [bool compressed = true]) {
    return point.getEncoded(compressed).map(
      (byte) => byte.toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static ECPoint pointFromHex(String hex) {
    final handler = ECCurve_secp256k1();
    return handler.curve.decodePoint(hex.hexToBytes())!;
  }
}
