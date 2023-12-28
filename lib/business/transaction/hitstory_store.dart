
import '../../model/history_entry.dart';
import '../../utils/database/db.dart';

class HistoryStore {

  /// add history entry
  static Future<bool> _add(IHistoryEntry entry) async {
    final rowsAffected = await CashuDB.sharedInstance.insert<IHistoryEntry>(entry);
    return rowsAffected == 1;
  }

  /// get history entries
  static Future<List<IHistoryEntry>> getHistory() async {
    return await CashuDB.sharedInstance.objects<IHistoryEntry>(
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
  }) async {
    var item = IHistoryEntry(
      amount: amount,
      type: type,
      value: value,
      mints: mints,
      timestamp: DateTime.now().millisecondsSinceEpoch.toDouble(),
    );
    _add(item);
    return item;
  }
}