
import '../../utils/database/db.dart';
import '../../utils/list_extension.dart';
import '../model/keyset_info.dart';

class KeysetStore {

  /// Adds a keyset collection
  static Future<bool> addOrReplaceKeysets(List<KeysetInfo> keysets) async {
    if (keysets.isEmpty) return false;
    List<bool> results = [];
    final keysetsChunks = keysets.toChunks(100);
    for (final chunk in keysetsChunks) {
      var rowsAffected = await CashuDB.sharedInstance.insertObjects<KeysetInfo>(chunk);
      results.add(rowsAffected == chunk.length);
    }
    return results.every((x) => x);
  }

  /// Returns a valid keyset object based on the parameters
  static Future<List<KeysetInfo>> getKeyset({String? mintURL, String? id, String? unit, bool? active}) async {
    final where = [];
    final whereArgs = [];

    if (mintURL != null && mintURL.isNotEmpty) {
      where.add(' mintURL = ? ');
      whereArgs.add(mintURL);
    }

    if (id != null && id.isNotEmpty) {
      where.add(' id = ? ');
      whereArgs.add(id);
    }

    if (unit != null && unit.isNotEmpty) {
      where.add(' unit = ? ');
      whereArgs.add(unit);
    }

    if (active != null) {
      where.add(' active = ? ');
      whereArgs.add(active);
    }

    final keysets = await CashuDB.sharedInstance.objects<KeysetInfo>(
      where: where.join('and'),
      whereArgs: whereArgs,
    );

    return keysets;
  }
}