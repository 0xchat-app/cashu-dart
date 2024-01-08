
import 'dart:async';

import 'package:bolt11_decoder/bolt11_decoder.dart';
import 'package:cashu_dart/business/transaction/hitstory_store.dart';
import 'package:cashu_dart/model/lightning_invoice.dart';

import '../../api/cashu_api.dart';
import '../../core/nuts/v0/nut_04.dart';
import '../../core/nuts/v1/nut_05.dart';
import '../../model/history_entry.dart';
import '../../model/invoice.dart';
import '../../model/invoice_listener.dart';
import '../../model/mint_model.dart';
import '../transaction/invoice_store.dart';
import '../transaction/transaction_helper.dart';

class InvoiceHandler {

  final _invoices = <Receipt>[];
  final _pendingInvoices = <Receipt>{};
  final List<InvoiceListener> _listeners = [];

  Timer? _checkTimer;

  Future<void> initialize() async {
    _invoices.addAll(await InvoiceStore.getAllInvoice());
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
      if (Cashu.isV1) {
        final quoteInfo = await Nut5.requestMeltQuote(
          mintURL: invoice.mintURL,
          request: invoice.request,
        );
        paid = quoteInfo.data?.paid ?? false;
      }

      if (paid) {
        if (await _exchangeCash(invoice)) {
          _deleteInvoice(invoice);
          await HistoryStore.addToHistory(
            amount: int.tryParse(invoice.amount) ?? 0,
            type: IHistoryType.lnInvoice,
            value: invoice.paymentKey,
            mints: [invoice.mintURL],
          );
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
      requestTokensAction: Cashu.isV1
          ? Nut4.requestTokensFromMint
          : Nut4.requestTokensFromMint
    );
    return proofs != null;
  }

  void _deleteInvoice(Receipt invoice) {
    _invoices.remove(invoice);
    InvoiceStore.deleteInvoice([invoice]);
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
