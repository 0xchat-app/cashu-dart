
import '../../utils/network/http_client.dart';
import '../../utils/tools.dart';
import 'define.dart';
import 'nut_00.dart';

class MintQuotePayload {
  MintQuotePayload(this.quote, this.request, this.paid, this.expiry);
  final String quote;
  final String request;
  final bool paid;

  /// Expiry timestamp in seconds, 0 means never expires
  final int expiry;

  static MintQuotePayload? fromServerMap(Map json) {
    final quote = Tools.getValueAs<String>(json, 'quote', '');
    final request = Tools.getValueAs<String>(json, 'request', '');
    final paid = Tools.getValueAs<bool>(json, 'paid', false);
    final expiry = Tools.getValueAs<int>(json, 'expiry', 0);
    if (quote.isEmpty || request.isEmpty) return null;
    return MintQuotePayload(quote, request, paid, expiry);
  }

  @override
  String toString() {
    return '${super.toString()}, quote: $quote, request: $request, paid: $paid, expiry: $expiry';
  }
}

class Nut4 {
  static Future<MintQuotePayload?> requestMintQuote({
    required String mintURL,
    required int amount,
    String method = 'bolt11',
    String unit = 'sat',
  }) async {
    return HTTPClient.post(
      nutURLJoin(mintURL, 'mint/quote/$method'),
      params: {
        'amount': amount.toString(),
        'unit': unit,
      },
      modelBuilder: (json) {
        if (json is! Map) return null;
        return MintQuotePayload.fromServerMap(json);
      },
    );
  }

  static Future<MintQuotePayload?> checkMintQuoteState({
    required String mintURL,
    required String quoteID,
    String method = 'bolt11',
  }) async {
    return HTTPClient.get(
      nutURLJoin(mintURL, 'mint/quote/$method/$quoteID'),
      modelBuilder: (json) {
        if (json is! Map) return null;
        return MintQuotePayload.fromServerMap(json);
      },
    );
  }

  static Future<List<BlindedSignature>?> requestTokensFromMint({
    required String mintURL,
    required String quote,
    required List<BlindedMessage> blindedMessages,
    String method = 'bolt11',
  }) async {
    return HTTPClient.post(
      nutURLJoin(mintURL, 'mint/$method'),
      params: {
        'quote': quote,
        'outputs': blindedMessages.map((e) {
          return {
            'id': e.id,
            'amount': e.amount,
            'B_': e.B_,
          };
        }).toList(),
      },
      modelBuilder: (json) {
        if (json is! Map) return null;
        final promises = Tools.getValueAs<List>(json, 'signatures', []);
        return promises.map((e) {
          if (e is! Map) return null;
          return BlindedSignature.fromServerMap(e);
        }).where((e) => e != null).toList().cast();
      },
    );
  }
}