
import 'dart:async';

import '../../api/cashu_api.dart';
import '../../api/v1/client.dart';
import '../../core/nuts/v0/nut_04.dart';
import '../../core/nuts/v1/nut_05.dart';
import '../../model/invoice.dart';
import '../../model/invoice_listener.dart';
import '../../model/mint_model.dart';
import '../transaction/invoice_store.dart';
import '../transaction/transaction_helper.dart';

class InvoiceHandler {

  List<Receipt> _invoices = [];
  final _pendingInvoices = <Receipt>{};
  final List<InvoiceListener> _listeners = [];

  Timer? _checkTimer;

  bool get isV1 => Cashu is CashuAPIV1Client;

  Future<void> initialize() async {
    _invoices = await InvoiceStore.getAllInvoice();
    _checkTimer = Timer.periodic(const Duration(seconds: 5), _periodicCheck);
  }

  void dispose() {
    _listeners.clear();
    _invoices.clear();
    _checkTimer?.cancel();
  }

  void addInvoice(Receipt invoice) {
    if (_invoiceExists(invoice)) return ;
    _invoices.add(invoice);
    _checkInvoice(invoice);
  }

  void _periodicCheck(Timer timer) async {
    final invoices = [..._invoices].reversed;
    for (var invoice in invoices) {
      _checkInvoice(invoice);
    }
  }

  Future<void> _checkInvoice(Receipt invoice) async {
    if (_pendingInvoices.contains(invoice)) return;
    _pendingInvoices.add(invoice);

    try {
      bool paid = true;
      if (isV1) {
        final quoteInfo = await Nut5.requestMeltQuote(
          mintURL: invoice.mintURL,
          request: invoice.request,
        );
        paid = true; //quoteInfo?.paid ?? false;
      }

      if (paid) {
        if (await _exchangeCash(invoice)) {
          _deleteInvoice(invoice);
          notifyListenerForPaidSuccess(invoice);
        }
      } else if (invoice.isExpired) {
        _deleteInvoice(invoice);
      }
    } catch (e) {
      // Handle exceptions
    } finally {
      _pendingInvoices.remove(invoice);
    }
  }

  Future<bool> _exchangeCash(Receipt invoice) async {
    final amount = int.tryParse(invoice.amount);
    if (amount == null) return false;
    final proofs = await TransactionHelper.requestTokensFromMint(
      mint: IMint(mintURL: invoice.mintURL),
      quoteID: invoice.redemptionKey,
      amount: amount,
      requestTokensAction: isV1 ? null : Nut4.requestTokensFromMint
    );
    return proofs != null;
  }

  void _deleteInvoice(Receipt invoice) {
    _invoices.remove(invoice);
    if (invoice is IInvoice) {
      InvoiceStore.deleteInvoice([invoice]);
    }
  }

  bool _invoiceExists(Receipt invoice) {
    return _invoices.any((element) => element.redemptionKey == invoice.redemptionKey);
  }

  void addListener(InvoiceListener listener) {
    _listeners.add(listener);
  }

  void removeListener(InvoiceListener listener) {
    _listeners.remove(listener);
  }

  void notifyListenerForPaidSuccess(Receipt receipt) {
    _listeners.forEach((e) {
      e.onInvoicePaid(receipt);
    });
  }
}
