
import 'dart:async';

import 'package:cashu_dart/business/wallet/cashu_manager.dart';
import 'package:cashu_dart/cashu_dart.dart';

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
    checkInvoice(invoice);
  }

  void _periodicCheck(Timer timer) async {
    final invoices = [..._invoices].reversed;
    for (var invoice in invoices) {
      checkInvoice(invoice);
    }
  }

  Future<bool> checkInvoice(Receipt invoice, [bool force = false]) async {

    if (!force) {
      if (_pendingInvoices.contains(invoice)) return false;
      _pendingInvoices.add(invoice);
    }

    try {
      bool paid = true;
      // if (invoice is IInvoice) {
      //   final response = await v1.Nut5.requestMeltQuote(
      //     mintURL: invoice.mintURL,
      //     request: invoice.request,
      //   );
      //   if (response.isSuccess) {
      //     final quoteInfo = response.data;
      //     invoice.paid = quoteInfo.paid;
      //     await InvoiceStore.addInvoice(invoice);
      //     paid = quoteInfo.paid;
      //   }
      // }

      if (paid) {
        final response = await _exchangeCash(invoice);
        if (response.isSuccess) {
          _deleteInvoice(invoice);
          if (response.data.isNotEmpty) {
            await HistoryStore.addToHistory(
              amount: int.tryParse(invoice.amount) ?? 0,
              type: IHistoryType.lnInvoice,
              value: invoice.paymentKey,
              mints: [invoice.mintURL],
              fee: 0,
            );
            invoiceOnPaidCallback?.call(invoice);
          }
          return true;
        } else if (response.code == ResponseCode.invoiceNotPaidError && invoice.isExpired) {
          _deleteInvoice(invoice);
        }
      }

    } catch (e) {
      // Handle exceptions
    } finally {
      _pendingInvoices.remove(invoice);
    }

    return false;
  }

  Future<CashuResponse<List<Proof>>> _exchangeCash(Receipt invoice) async {
    final amount = int.tryParse(invoice.amount);
    if (amount == null) return CashuResponse.fromErrorMsg('Amount is null.');

    final mint = await CashuManager.shared.getMint(invoice.mintURL);
    if (mint == null) return CashuResponse.fromErrorMsg('Mint is null.');

    return TransactionHelper.requestTokensFromMint(
      mint: mint,
      quoteID: invoice.redemptionKey,
      amount: amount,
    );
  }

  void _deleteInvoice(Receipt invoice) {
    _invoices.remove(invoice);
    InvoiceStore.deleteInvoice([invoice]);
  }

  bool _invoiceExists(Receipt invoice) {
    return _invoices.any((element) => element.redemptionKey == invoice.redemptionKey);
  }
}
