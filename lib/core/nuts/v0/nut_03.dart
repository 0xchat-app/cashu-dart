
import '../../../model/invoice.dart';
import '../../../utils/network/http_client.dart';
import '../../../utils/tools.dart';
import '../define.dart';
import '../nut_00.dart';

class Nut3 {
  static Future<IInvoice?> requestMintQuote({
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
        return IInvoice.fromServerMap(json, mintURL, amount.toString());
      },
    );
  }
}