
import 'invoice.dart';
import 'mint_model.dart';

abstract mixin class CashuListener {
  void onInvoicePaid(Receipt receipt) { }
  void onBalanceChanged(IMint mint) { }
}