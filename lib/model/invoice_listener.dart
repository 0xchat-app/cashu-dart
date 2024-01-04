
import 'invoice.dart';

abstract mixin class InvoiceListener {
  void onInvoicePaid(Receipt receipt);
}