
import 'dart:async';

import 'package:cashu_dart/model/mint_model.dart';
import 'package:cashu_dart/utils/cashu_token_helper.dart';
import 'package:cashu_dart/utils/tools.dart';

import '../../core/mint.dart';
import '../../core/nuts/nut_01.dart';
import '../../utils/database/db.dart';
import '../mint/mint_store.dart';
import '../proof/proof_store.dart';

class WalletManager {

  static final WalletManager shared = WalletManager._internal();
  WalletManager._internal();

  late IMint defaultMint;

  /// key: mintUrl
  final Map<String, CashuMint> mints = {};

  /// key: mintUrl, value: { keySetId: [MintKeys] }
  final Map<String, Map<String, MintKeys>> _mintKeysMap = {};

  final ProofStore proofStore = ProofStore();

  Completer setupFinish = Completer();

  Future setup(String identify, {int? dbVersion, String? dbPassword}) async {
    // DB setup
    await CashuDB.sharedInstance.open('cashu-$identify.db', version: dbVersion, password: dbPassword);

    // Mint setup
    final mints = await MintStore.getMints();
    if (mints.isEmpty) {
      // add default mint
      const enutsMintURL = 'https://legend.lnbits.com/cashu/api/v1/AptDNABNBXv8gpuywhx6NV';
      final result = await MintStore.addMint(enutsMintURL);
      if (result != null) {
        defaultMint = result;
      }
    } else {
      defaultMint = mints.first;
    }

    print('[Cashu - setup] finished');
    setupFinish.complete();
  }

  void setKeys(String mintUrl, MintKeys keys, [String? keySetId]) {
    keySetId ??= keys.deriveKeysetId();

    final keysMap = _mintKeysMap[mintUrl] ?? {};
    _mintKeysMap[mintUrl] ??= keysMap;

    if (keysMap[keySetId] == null) {
      keysMap[keySetId] = keys;
      final mint = mints[mintUrl];
      if (mint?.keySetId != keySetId) {
        mint?.updateKeys(keys);
      }
    }
  }

  Future<CashuMint> getMint(String mintURL) async {
    if (mints[mintURL] != null) return mints[mintURL]!;
    final mint = CashuMint(mintURL);
    final keys = await Nut1.requestKeys(mintURL: mintURL);
    if (keys != null) {
      // setKeys(mintURL, keys);
    }
    mints[mintURL] = mint;
    return mint;
  }

  // Future<String?> getCurrentKeySetId(String mintURL) async {
  //   final keys = await Nut1.requestKeys(mintURL: mintURL);
  //   final keySetId = keys?.deriveKeysetId();
  //   if (keys != null) {
  //     setKeys(mintURL, keys, keySetId);
  //   }
  //   return keySetId;
  // }
}