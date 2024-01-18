
import 'dart:async';

import '../../api/cashu_api.dart';
import '../../core/nuts/nut_00.dart';
import '../../core/nuts/v0/nut.dart' as v0;
import '../../core/nuts/v1/nut.dart' as v1;
import '../../model/history_entry.dart';
import '../../model/invoice.dart';
import '../../model/mint_model.dart';
import '../transaction/hitstory_store.dart';
import '../transaction/invoice_store.dart';
import '../transaction/transaction_helper.dart';

class InvoiceHandler {

  final _invoices = <Receipt>[];
  final _pendingInvoices = <Receipt>{};
  Function(Receipt invoice)? invoiceOnPaidCallback;

  Timer? _checkTimer;

  Future<void> initialize() async {
    _invoices.addAll(await InvoiceStore.getAllInvoice());
    _checkTimer = Timer.periodic(const Duration(seconds: 5), _periodicCheck);
  }

  void dispose() {
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
        final quoteInfo = await v1.Nut5.requestMeltQuote(
          mintURL: invoice.mintURL,
          request: invoice.request,
        );
        paid = quoteInfo.data.paid;
      }

      if (paid) {
        final newProof = await _exchangeCash(invoice);
        if (newProof != null) {
          _deleteInvoice(invoice);
          if (newProof.isNotEmpty) {
            await HistoryStore.addToHistory(
              amount: int.tryParse(invoice.amount) ?? 0,
              type: IHistoryType.lnInvoice,
              value: invoice.paymentKey,
              mints: [invoice.mintURL],
              fee: 0,
            );
            invoiceOnPaidCallback?.call(invoice);
          }
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

  Future<List<Proof>?> _exchangeCash(Receipt invoice) async {
    final amount = int.tryParse(invoice.amount);
    if (amount == null) return null;
    final proofs = await TransactionHelper.requestTokensFromMint(
      mint: IMint(mintURL: invoice.mintURL),
      quoteID: invoice.redemptionKey,
      amount: amount,
      requestTokensAction: Cashu.isV1
          ? v1.Nut4.requestTokensFromMint
          : v0.Nut4.requestTokensFromMint
    );
    return proofs;
  }

  void _deleteInvoice(Receipt invoice) {
    _invoices.remove(invoice);
    InvoiceStore.deleteInvoice([invoice]);
  }

  bool _invoiceExists(Receipt invoice) {
    return _invoices.any((element) => element.redemptionKey == invoice.redemptionKey);
  }
}
