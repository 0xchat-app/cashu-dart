
import '../../business/wallet/cashu_manager.dart';
import '../../model/mint_model.dart';

class CashuMintAPI {

  /// Returns a list of all mints.
  static Future<List<IMint>> mintList() async {
    await CashuManager.shared.setupFinish.future;
    return CashuManager.shared.mints;
  }

  /// Adds a new mint with the given URL.
  /// Throws an exception if the URL does not start with 'https://'.
  /// Returns the newly added mint, or null if the operation fails.
  static Future<IMint?> addMint(String mintURL) async {
    await CashuManager.shared.setupFinish.future;
    return await CashuManager.shared.addMint(mintURL);
  }

  /// Deletes the specified mint.
  /// Returns true if the deletion is successful.
  static Future<bool> deleteMint(IMint mint) async {
    await CashuManager.shared.setupFinish.future;
    return CashuManager.shared.deleteMint(mint);
  }

  /// Edits the name of the specified mint.
  static editMintName(IMint mint, String name) async {
    await CashuManager.shared.setupFinish.future;
    if (mint.name == name) return ;
    mint.name = name;
    CashuManager.shared.updateMintName(mint);
  }
}