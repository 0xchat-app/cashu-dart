
import 'history_entry.dart';
import 'invoice.dart';
import 'mint_model.dart';

abstract mixin class CashuListener {
  void handleInvoicePaid(Receipt receipt) { }
  void handleBalanceChanged(IMint mint) { }
  void handleMintListChanged(List<IMint> mints) { }
  void handlePaymentCompleted(String paymentKey) { }
  void handleHistoryChanged() { }
}