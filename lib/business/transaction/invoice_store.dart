

import 'package:cashu_dart/model/invoice.dart';
import 'package:cashu_dart/utils/list_extension.dart';

import '../../utils/database/db.dart';

class InvoiceStore {
  static Future<bool> addInvoice(IInvoice invoice) async {
    final rowsAffected = await CashuDB.sharedInstance.insert<IInvoice>(invoice);
    return rowsAffected == 1;
  }

  static Future<List<IInvoice>> getAllInvoice() {
    return CashuDB.sharedInstance.objects();
  }

  static Future<bool> deleteInvoice(List<IInvoice> delInvoices) async {
    if (delInvoices.isEmpty) return true;

    var rowsAffected = 0;

    final map = delInvoices.groupBy((e) => e.mintURL);
    await Future.forEach(map.keys, (mintURL) async {
      final invoices = map[mintURL] ?? [];
      final quotes = invoices.map((e) => e.quote).toList();
      rowsAffected += await CashuDB.sharedInstance.delete<IInvoice>(
        where: ' mintURL = ? and quote in (?)',
        whereArgs: [mintURL, quotes.join(',')],
      );
    });

    return rowsAffected == delInvoices.length;
  }
}