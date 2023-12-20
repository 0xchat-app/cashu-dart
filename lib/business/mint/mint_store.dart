
import 'package:cashu_dart/core/mint.dart';
import 'package:cashu_dart/utils/list_extension.dart';

import '../../model/define.dart';
import '../../model/mint_model.dart';
import '../../utils/database/db.dart';
import '../../utils/tools.dart';

class MintStore {

  static Future<List<IMint>> getMints() async {
    return CashuDB.sharedInstance.objects<IMint>();
  }

  static Future<List<String>> getMintsUrls({bool asObj = false}) async {
    var results = await CashuDB.sharedInstance.objects<IMint>(
      distinct: true,
      columns: ['mintURL'],
    );

    if (asObj) {
      return results.map((m) => m.mintURL).toList();
    } else {
      return results.map((m) => m.mintURL).toList();
    }
  }

  static Future<IMint?> addMint(String mintURL, [String id = '']) async {
    if (id.isEmpty) {
      final MintKeys? keys = await CashuMint(mintURL).getKeys();
      id = keys?.deriveKeysetId() ?? id;
    }
    if (id.isEmpty) return null;

    final mint = IMint(id: id, mintURL: mintURL);
    var rowsAffected = await CashuDB.sharedInstance.insert<IMint>(mint,);
    return rowsAffected == 1 ? mint : null;
  }

  static Future<bool> addMints(List<IMint> mints) async {
    if (mints.isEmpty) return false;
    List<bool> results = [];
    final mintsChunks = mints.toChunks(100);
    for (final chunk in mintsChunks) {
      var rowsAffected = await CashuDB.sharedInstance.insertObjects<IMint>(chunk);
      results.add(rowsAffected == chunk.length);
    }
    return results.every((x) => x);
  }

  static Future<bool> hasMints() async {
    final result = await CashuDB.sharedInstance.objects<IMint>();
    return result.isNotEmpty;
  }

  static Future<IMint?> getMintByKeySetId(String id) async {
    var results = await CashuDB.sharedInstance.objects<IMint>(
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  static Future<List<IMint>> getMintIdsByUrl(String mintURL) async {
    return CashuDB.sharedInstance.objects<IMint>(
      where: 'mintURL = ?',
      whereArgs: [mintURL],
    );
  }

  static Future<bool> deleteMint(String mintURL) async {
    var rowsAffected = await CashuDB.sharedInstance.delete<IMint>(
      where: 'mintURL = ?',
      whereArgs: [mintURL],
    );
    return rowsAffected == 1;
  }
}