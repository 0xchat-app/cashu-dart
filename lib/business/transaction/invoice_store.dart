
import 'package:cashu_dart/utils/list_extension.dart';

import '../../model/invoice.dart';
import '../../model/lightning_invoice.dart';
import '../../utils/database/db.dart';

class InvoiceStore {
  static Future<bool> addInvoice(Receipt invoice) async {
    int rowsAffected = 0;
    if (invoice is IInvoice) {
      rowsAffected = await CashuDB.sharedInstance.insert<IInvoice>(invoice);
    } else if (invoice is LightningInvoice) {
      rowsAffected = await CashuDB.sharedInstance.insert<LightningInvoice>(invoice);
    }
    return rowsAffected == 1;
  }

  static Future<List<Receipt>> getAllInvoice() async {
    return [
      ... await CashuDB.sharedInstance.objects<IInvoice>(),
      ... await CashuDB.sharedInstance.objects<LightningInvoice>(),
    ];
  }

  static Future<bool> deleteInvoice(List<Receipt> delInvoices) async {
    if (delInvoices.isEmpty) return true;

    var rowsAffected = 0;

    final map = delInvoices.groupBy((e) => e.mintURL);
    await Future.forEach(map.keys, (mintURL) async {
      final invoices = map[mintURL] ?? [];
      if (invoices.every((e) => e is IInvoice)) {
        final list = invoices.cast<IInvoice>();
        final placeholders = list.map((_) => '?').toList().join(',');
        final quotes = list.map((e) => e.quote).toList();
        rowsAffected += await CashuDB.sharedInstance.delete<IInvoice>(
          where: ' mintURL = ? and quote in ($placeholders)',
          whereArgs: [mintURL, ...quotes],
        );
      } else if (invoices.every((e) => e is LightningInvoice)) {
        final list = invoices.cast<LightningInvoice>();
        final placeholders = list.map((_) => '?').toList().join(',');
        final hash = list.map((e) => e.hash).toList();
        rowsAffected += await CashuDB.sharedInstance.delete<LightningInvoice>(
          where: ' mintURL = ? and hash in ($placeholders)',
          whereArgs: [mintURL, ...hash],
        );
      }
    });

    return rowsAffected == delInvoices.length;
  }
}