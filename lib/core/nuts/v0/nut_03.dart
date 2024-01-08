
import '../../../model/lightning_invoice.dart';
import '../../../utils/network/http_client.dart';
import '../define.dart';

class Nut3 {
  /// Starts a minting process by requesting an invoice from the mint
  /// [amount] Amount requesting for mint.
  /// Returns the mint will create and return a Lightning invoice for the specified amount
  static Future<CashuResponse<LightningInvoice>> requestMintInvoice({
    required String mintURL,
    required int amount,
  }) async {
    return HTTPClient.get(
      nutURLJoin(mintURL, 'mint', version: ''),
      query: {
        'amount': amount.toString(),
      },
      modelBuilder: (json) {
        if (json is! Map) return null;
        return LightningInvoice.fromServerMap(json, mintURL, amount.toString());
      },
    );
  }
}