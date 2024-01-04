
import 'invoice.dart';

abstract class InvoiceListener {
  void onInvoicePaid(Receipt receipt);
}