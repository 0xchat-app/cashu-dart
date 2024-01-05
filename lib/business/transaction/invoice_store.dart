
import 'package:cashu_dart/utils/list_extension.dart';

import '../../api/cashu_api.dart';
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

  static Future<List<Receipt>> getAllInvoice() {
    if (Cashu.isV1) {
      return CashuDB.sharedInstance.objects<IInvoice>();
    } else {
      return CashuDB.sharedInstance.objects<LightningInvoice>();
    }
  }

  static Future<bool> deleteInvoice(List<Receipt> delInvoices) async {
    if (delInvoices.isEmpty) return true;

    var rowsAffected = 0;

    final map = delInvoices.groupBy((e) => e.mintURL);
    await Future.forEach(map.keys, (mintURL) async {
      final invoices = map[mintURL] ?? [];
      if (invoices is List<IInvoice>) {
        final quotes = invoices.map((e) => '"${e.quote}"').toList().join(',');
        rowsAffected += await CashuDB.sharedInstance.delete<IInvoice>(
          where: ' mintURL = ? and quote in ($quotes)',
          whereArgs: [mintURL],
        );
      } else if (invoices is List<LightningInvoice>) {
        final hash = invoices.map((e) => '"${e.hash}"').toList().join(',');
        rowsAffected += await CashuDB.sharedInstance.delete<IInvoice>(
          where: ' mintURL = ? and hash in ($hash)',
          whereArgs: [mintURL],
        );
      }
    });

    return rowsAffected == delInvoices.length;
  }
}