
import '../../utils/network/http_client.dart';
import '../../utils/tools.dart';
import 'nut_00.dart';

class Nut4 {
  /// Requests the mint to perform token minting after the LN invoice has been paid
  /// [payloads] outputs (Blinded messages) that can be written
  /// [hash] hash (id) used for by the mint to keep track of wether the invoice has been paid yet
  /// Returns serialized blinded signatures
  static Future<List<BlindedSignature>?> requestTokensFromMint({
    required String mintURL,
    required List<BlindedMessage> blindedMessages,
    required String hash,
  }) async {
    return HTTPClient.post(
      '$mintURL/mint',
      query: {'hash': hash},
      params: {'outputs': blindedMessages.map((e) => e.toJson()).toList()},
      modelBuilder: (json) {
        if (json is! Map) return null;
        final promises = Tools.getValueAs<List>(json, 'promises', []);
        return promises.map((e) {
          if (e is! Map) return null;
          return BlindedSignature.fromServerMap(e);
        }).where((e) => e != null).toList().cast();
      },
    );
  }
}