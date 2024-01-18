import 'dart:async';

import '../../core/keyset_store.dart';
import '../../model/invoice.dart';
import '../../model/invoice_listener.dart';
import '../../model/mint_model.dart';
import '../../utils/database/db.dart';
import '../mint/mint_helper.dart';
import '../mint/mint_info_store.dart';
import '../mint/mint_store.dart';
import '../proof/proof_helper.dart';
import 'invoice_handler.dart';

class CashuManager {
  static final CashuManager shared = CashuManager._internal();
  CashuManager._internal();

  List<String>? defaultMint;

  final List<IMint> mints = [];
  InvoiceHandler invoiceHandler = InvoiceHandler();
  final List<CashuListener> _listeners = [];

  Completer setupFinish = Completer();

  Future<void> setup(String identify, {
    int dbVersion = 1,
    String? dbPassword,
    List<String>? defaultMint,
  }) async {
    try {
      this.defaultMint = defaultMint;
      await CashuDB.sharedInstance.open('cashu-$identify.db', version: dbVersion, password: dbPassword);
      await setupMint();
      await setupBalance();
      await invoiceHandler.initialize();
      invoiceHandler.invoiceOnPaidCallback = notifyListenerForPaidSuccess;
      setupFinish.complete();
      print('[I][Cashu - setup] Finished');
    } catch (e) {
      print('[E][Cashu - setup] $e');
    }
  }

  void clean() {
    setupFinish = Completer();
    CashuDB.sharedInstance.closeDatabase();
    mints.clear();
    invoiceHandler.dispose();
  }

  Future<void> setupMint() async {
    try {
      List<IMint> dbMints = await MintStore.getMints();
      if (dbMints.isEmpty) {
        dbMints = await _addDefaultMint();
      }
      await _initializeMints(dbMints);
    } catch (e) {
      print('[E][Cashu - setupMint] $e');
    }
  }

  Future<List<IMint>> _addDefaultMint() async {
    defaultMint ??= ['https://testnut.cashu.space'];
    final result = <IMint>[];
    for (final mintURL in defaultMint!) {
      final mint = IMint(mintURL: mintURL);
      await MintStore.addMints([mint]);
      result.add(mint);
    }
    return result;
  }

  Future<void> _initializeMints(List<IMint> dbMints) async {
    for (IMint mint in dbMints) {
      await _setupMintInfo(mint);
      await _setupMintKeyset(mint);
      mints.add(mint);
    }
  }

  Future<void> _setupMintInfo(IMint mint) async {
    final info = await MintInfoStore.getMintInfo(mint.mintURL);
    if (info != null) {
      mint.info = info;
    }
    MintHelper.updateMintInfoFromRemote(mint);
  }

  Future<void> _setupMintKeyset(IMint mint) async {
    final keysets = await KeysetStore.getKeyset(mintURL: mint.mintURL, active: true);
    for (var keyset in keysets) {
      mint.updateKeysetId(keyset.id, keyset.unit);
    }
    MintHelper.updateMintKeysetFromRemote(mint);
  }

  Future<void> setupBalance() async {
    for (IMint mint in mints) {
      await updateMintBalance(mint);
    }
  }

  Future<IMint?> getMint(String mintURL) async {
    final url = MintHelper.getMintURL(mintURL);
    for (IMint mint in mints) {
      if (mint.mintURL == url) {
        return mint;
      }
    }
    try {
      return addMint(mintURL);
    } catch (_) {
      return null;
    }
  }

  Future<IMint?> addMint(String mintURL) async {

    if (!mintURL.startsWith('https://')) throw Exception('mintURL must starts with \'https://\'');

    if (mints.any((element) => element.mintURL == mintURL)) {
      return null;
    }

    final url = MintHelper.getMintURL(mintURL);

    final mint = IMint(mintURL: url);

    final fetchSuccess = await MintHelper.updateMintInfoFromRemote(mint);
    if (!fetchSuccess) return null;
    mint.name = mint.info?.name ?? '';

    MintHelper.updateMintKeysetFromRemote(mint);

    mints.add(mint);
    final saveSuccess = await MintStore.addMints([mint]);
    if (!saveSuccess) return null;

    return mint;
  }

  Future<bool> updateMintName(IMint mint) async {
    final index = mints.indexWhere((element) => element.mintURL == mint.mintURL);
    if (index < 0) {
      return false;
    }
    mints[index].name = mint.name;
    return await MintStore.updateMint(mint);
  }

  Future updateMintBalance(IMint mint) async {
    final index = mints.indexWhere((element) => element.mintURL == mint.mintURL);
    if (index < 0) {
      return false;
    }
    var total = 0;
    final proofs = await ProofHelper.getProofs(mint.mintURL);
    for (final proof in proofs) {
      total += proof.amountNum;
    }
    mints[index].balance = total;
    notifyListenerForBalanceChanged(mint);
  }

  Future<bool> deleteMint(IMint mint) async {
    try {
      final target = mints.firstWhere((element) => element.mintURL == mint.mintURL);
      mints.remove(target);
      return await MintStore.deleteMint(target.mintURL);
    } catch (_) {
      return false;
    }
  }

  void addListener(CashuListener listener) {
    _listeners.add(listener);
  }

  void removeListener(CashuListener listener) {
    _listeners.remove(listener);
  }

  void notifyListenerForPaidSuccess(Receipt receipt) {
    _listeners.forEach((e) {
      e.onInvoicePaid(receipt);
    });
  }

  void notifyListenerForBalanceChanged(IMint mint) {
    _listeners.forEach((e) {
      e.onBalanceChanged(mint);
    });
  }
}
