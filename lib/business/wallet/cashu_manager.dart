
import 'dart:async';

import '../../core/keyset_store.dart';
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

  IMint? defaultMint;

  /// key: mintUrl
  final List<IMint> mints = [];

  InvoiceHandler invoiceHandler = InvoiceHandler();

  Completer setupFinish = Completer();

  Future setup(String identify, {int dbVersion = 1, String? dbPassword}) async {

    // DB setup
    await CashuDB.sharedInstance.open(
      'cashu-$identify.db',
      version: dbVersion,
      password: dbPassword,
    );

    // Mint setup
    await setupMint();

    // Proofs setup
    await setupProofs();

    // invoice handler setup
    await invoiceHandler.setup();

    print('[I][Cashu - setup] finished');
    setupFinish.complete();
  }

  clean() {
    CashuDB.sharedInstance.closDatabase();
    mints.clear();
    invoiceHandler.invalidate();
  }

  Future setupMint() async {
    // get mint list from db
    final mints = await MintStore.getMints();

    if (mints.isEmpty) {
      // add default mint if empty
      const enutsMintURL = 'https://testnut.cashu.space';
      final mint = await MintStore.addMint(enutsMintURL);
      if (mint != null) {
        mints.add(mint);
      }
    }

    // setup mint
    await Future.forEach(mints, (mint) async {
      // setup mint info
      final info = await MintInfoStore.getMintInfo(mint.mintURL);
      if (info != null) {
        mint.info = info;
      }
      MintHelper.updateMintInfoFromRemote(mint);

      // setup mint keysetId
      final keysets = await KeysetStore.getKeyset(mintURL: mint.mintURL, active: true);
      for (var keyset in keysets) {
        mint.updateKeysetId(keyset.id, keyset.unit);
      }
      MintHelper.updateMintKeysetFromRemote(mint);

      this.mints.add(mint);
    });

    // set default mint
    defaultMint = mints.first;
  }

  Future setupProofs() async {
    final mints = [...this.mints];
    await Future.forEach(mints, (mint) async {
      var total = 0;
      final proofs = await ProofHelper.getProofs(mint.mintURL);
      for (final proof in proofs) {
        total += proof.amountNum;
      }
      mint.balance = total;
    });
  }

  Future<IMint?> getMint(String mintURL) async {
    final url = MintHelper.getMintURL(mintURL);
    for (var mint in mints) {
      if (mint.mintURL == url) return mint;
    }
    return null;
  }

  Future<bool> addMint(IMint mint) async {
    if (mints.any((element) => element.mintURL == mint.mintURL)) {
      return false;
    }
    mints.add(mint);
    return MintStore.addMints([mint]);
  }

  Future<bool> updateMint(IMint mint) async {
    final index = mints.indexWhere((element) => element.mintURL == mint.mintURL);
    if (index < 0) return false;

    final target = mints[index];
    if (target != mint) {
      mints[index] = mint;
    }

    return MintStore.updateMint(mint);
  }

  Future<bool> deleteMint(IMint mint) async {
    try {
      final target = mints.firstWhere((element) => element.mintURL == mint.mintURL);
      mints.remove(target);
      return MintStore.deleteMint(target.mintURL);
    } catch(_) {
      return false;
    }
  }
}