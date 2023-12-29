
import 'dart:async';

import '../../core/nuts/nut_05.dart';
import '../../model/invoice.dart';
import '../../model/mint_model.dart';
import '../transaction/invoice_store.dart';
import '../transaction/transaction_helper.dart';

class InvoiceHandler {

  List<IInvoice> _invoices = [];
  final _pendingInvoices = <IInvoice>{};
  final _onSuccessCallbacks = <String, Function()>{};
  Timer? _checkTimer;

  Future<void> initialize() async {
    _invoices = await InvoiceStore.getAllInvoice();
    _checkTimer = Timer.periodic(const Duration(seconds: 5), _periodicCheck);
  }

  void dispose() {
    _onSuccessCallbacks.clear();
    _invoices.clear();
    _checkTimer?.cancel();
  }

  void addInvoice(IInvoice invoice, [Function()? onSuccess]) {
    if (onSuccess != null) {
      _onSuccessCallbacks[invoice.quote] = onSuccess;
    }
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

  Future<void> _checkInvoice(IInvoice invoice) async {
    if (_pendingInvoices.contains(invoice)) return;
    _pendingInvoices.add(invoice);

    try {
      final quoteInfo = await Nut5.requestMeltQuote(
        mintURL: invoice.mintURL,
        request: invoice.request,
      );

      // if (quoteInfo?.paid ?? false) {
      if (true) {
        if (await _exchangeCash(invoice)) {
          _deleteInvoice(invoice);
          _onSuccessCallbacks.remove(invoice.quote)?.call();
        }
      } else if (_isExpired(invoice)) {
        _deleteInvoice(invoice);
      }
    } catch (e) {
      // Handle exceptions
    } finally {
      _pendingInvoices.remove(invoice);
    }
  }

  bool _isExpired(IInvoice invoice) {
    return invoice.expiry != 0 &&
        invoice.expiry < DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  Future<bool> _exchangeCash(IInvoice invoice) async {
    final amount = int.tryParse(invoice.amount);
    if (amount == null) return false;
    final proofs = await TransactionHelper.requestTokensFromMint(
      mint: IMint(mintURL: invoice.mintURL),
      quoteID: invoice.quote,
      amount: amount,
    );
    return proofs != null;
  }

  void _deleteInvoice(IInvoice invoice) {
    _invoices.remove(invoice);
    InvoiceStore.deleteInvoice([invoice]);
  }

  bool _invoiceExists(IInvoice invoice) {
    return _invoices.any((element) => element.quote == invoice.quote);
  }
}
