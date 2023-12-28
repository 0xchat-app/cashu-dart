
import 'dart:async';

import '../../core/nuts/nut_05.dart';
import '../../model/invoice.dart';
import '../../model/mint_model.dart';
import '../transaction/invoice_store.dart';
import '../transaction/transaction_helper.dart';

class InvoiceHandler {

  List<IInvoice> invoices = [];
  Set<IInvoice> requestingInvoices = {};
  Map<String, Function()> successCallback = {};
  Timer? checkTimer;

  Future setup() async {
    invoices = await InvoiceStore.getAllInvoice();
    checkTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      checkInvoices();
    });
  }

  invalidate() {
    successCallback.clear();
    invoices.clear();
    checkTimer?.cancel();
  }

  void addInvoice(IInvoice invoice, [Function()? successCallback]) {
    if (successCallback != null) {
      this.successCallback[invoice.quote] = successCallback;
    }
    if (invoices.any((element) => element.quote == invoice.quote)) return ;
    invoices.add(invoice);
    checkInvoice(invoice);
  }

  void checkInvoices() async {
    final invoices = [...this.invoices].reversed;
    for (var invoice in invoices) {
      checkInvoice(invoice);
    }
  }

  void checkInvoice(IInvoice invoice) async {
    if (requestingInvoices.contains(invoice)) return ;
    requestingInvoices.add(invoice);

    final quoteInfo = await Nut5.requestMeltQuote(
      mintURL: invoice.mintURL,
      request: invoice.request,
    );
    requestingInvoices.remove(invoice);
    if (quoteInfo == null) return ;

    if (quoteInfo.paid) {
      bool exchanged = await exchangeCash(invoice);
      if (exchanged) {
        deleteInvoice(invoice);
        final fn = successCallback.remove(invoice.quote);
        fn?.call();
      }
    } else if (invoice.expiry == 0 || isExpired(invoice)) {
      deleteInvoice(invoice);
    }
  }

  bool isExpired(IInvoice invoice) {
    return invoice.expiry != 0
        && invoice.expiry < DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  Future<bool> exchangeCash(IInvoice invoice) async {
    final amount = int.tryParse(invoice.amount);
    if (amount == null) return false;
    final proofs = await TransactionHelper.requestTokensFromMint(
      mint: IMint(mintURL: invoice.mintURL),
      quoteID: invoice.quote,
      amount: amount,
    );
    return proofs != null;
  }

  void deleteInvoice(IInvoice invoice) {
    invoices.remove(invoice);
    InvoiceStore.deleteInvoice([invoice]);
  }
}