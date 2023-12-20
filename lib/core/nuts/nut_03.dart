
import '../../utils/network/http_client.dart';
import '../../utils/tools.dart';

typedef LnInvoicePayload = ({String pr, String hashValue});

class Nut3 {
  /// Starts a minting process by requesting an invoice from the mint
  /// [amount] Amount requesting for mint.
  /// Returns the mint will create and return a Lightning invoice for the specified amount
  static Future<LnInvoicePayload?> requestMintInvoice({
    required String mintURL,
    required int amount,
  }) async {
    return HTTPClient.get(
      '$mintURL/mint',
      query: {'amount': amount.toString()},
      modelBuilder: (json) {
        if (json is! Map) return null;
        final pr = Tools.getValueAs<String>(json, 'pr', '');
        final hashValue =Tools.getValueAs<String>(json, 'hash', '');
        return (pr: pr, hashValue: hashValue);
      },
    );
  }
}