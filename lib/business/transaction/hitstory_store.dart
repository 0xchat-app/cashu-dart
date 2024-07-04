
import 'package:cashu_dart/business/wallet/cashu_manager.dart';

import '../../model/history_entry.dart';
import '../../model/invoice.dart';
import '../../utils/database/db.dart';

class HistoryStore {

  /// add history entry
  static Future<bool> _add(IHistoryEntry entry) async {
    final rowsAffected = await CashuDB.sharedInstance.insert<IHistoryEntry>(entry);
    return rowsAffected == 1;
  }

  /// get history entries
  static Future<List<IHistoryEntry>> getHistory({
    List<String> value = const [],
  }) async {
    final where = [];

    if (value.isNotEmpty) {
      value = value.map((e) => '"$e"').toList();
      where.add(' value in (${value.join(',')}) ');
    }

    return await CashuDB.sharedInstance.objects<IHistoryEntry>(
      where: where.isNotEmpty ? where.join(' and ') : null,
      orderBy: 'timestamp desc',
    );
  }

  /// update history entries
  static updateHistoryEntry(IHistoryEntry newEntry) async {
    final rowsAffected = await CashuDB.sharedInstance.update<IHistoryEntry>(newEntry);
    return rowsAffected == 1;
  }

  static Future<IHistoryEntry> addToHistory({
    required num amount,
    required IHistoryType type,
    required String value,
    required List<String> mints,
    num? fee,
    bool? isSpent,
  }) async {
    var item = IHistoryEntry(
      amount: amount,
      type: type,
      value: value,
      mints: mints,
      timestamp: DateTime.now().millisecondsSinceEpoch.toDouble(),
      fee: fee,
      isSpent: isSpent,
    );
    await _add(item);
    CashuManager.shared.notifyListenerForHistoryChanged();
    return item;
  }

  static deleteHistory(List<String> ids) async {
    await CashuDB.sharedInstance.delete<IHistoryEntry>(
      where: 'id in (${ids.map((e) => '"$e"').join(',')})',
    );
    CashuManager.shared.notifyListenerForHistoryChanged();
  }

  static Future<bool> hasReceiptRedeemHistory(Receipt receipt) async {
    final result = await HistoryStore.getHistory(value: [receipt.paymentKey]);
    return result.any((history) => history.amount > 0);
  }
}