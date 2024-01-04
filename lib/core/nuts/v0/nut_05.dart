
import '../../../utils/network/http_client.dart';
import '../../../utils/tools.dart';
import '../define.dart';
import '../nut_00.dart';

class MeltQuotePayload {
  MeltQuotePayload(this.quote, this.amount, this.fee, this.paid, this.expiry);
  final String quote;
  final String amount;
  final String fee;
  final bool paid;
  final int expiry;

  static MeltQuotePayload? fromServerMap(Map json) {
    final quote = Tools.getValueAs<String>(json, 'quote', '');
    final amount = Tools.getValueAs<int>(json, 'amount', 0).toString();
    final fee = Tools.getValueAs<int>(json, 'fee_reserve', 0).toString();
    final paid = Tools.getValueAs<bool>(json, 'paid', false);
    final expiry = Tools.getValueAs<int>(json, 'expiry', 0);
    if (quote.isEmpty) return null;
    return MeltQuotePayload(quote, amount, fee, paid, expiry);
  }
}

class Nut5 {

}