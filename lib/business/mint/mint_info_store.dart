
import '../../model/mint_info.dart';
import '../../utils/database/db.dart';

class MintInfoStore {

  static Future<MintInfo?> getMintInfo(String mintURL) async {
    final mintInfo = await CashuDB.sharedInstance.objects<MintInfo>(
      where: 'mintURL = ?',
      whereArgs: [mintURL],
    );
    return mintInfo.firstOrNull;
  }

  static Future<bool> addMintInfo(MintInfo info) async {
    var rowsAffected = await CashuDB.sharedInstance.insert<MintInfo>(info);
    return rowsAffected == 1;
  }

  static Future<bool> deleteMint(String mintURL) async {
    var rowsAffected = await CashuDB.sharedInstance.delete<MintInfo>(
      where: 'mintURL = ?',
      whereArgs: [mintURL],
    );
    return rowsAffected == 1;
  }
}