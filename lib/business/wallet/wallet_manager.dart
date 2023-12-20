
import 'dart:async';

import 'package:cashu_dart/model/define.dart';
import 'package:cashu_dart/model/mint_model.dart';
import 'package:cashu_dart/utils/cashu_token_helper.dart';
import 'package:cashu_dart/utils/tools.dart';

import '../../core/mint.dart';
import '../../core/wallet.dart';
import '../../utils/database/db.dart';
import '../mint/mint_store.dart';
import '../proof/proof_store.dart';

class WalletManager {

  static final WalletManager shared = WalletManager._internal();
  WalletManager._internal();

  late IMint defaultMint;

  /// key: mintUrl
  final Map<String, CashuWallet> _wallets = {};

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
      if (_wallets[mintUrl]?.keysetId != keySetId) {
        _wallets[mintUrl]?.keys = keys;
      }
    }
  }

  Future<CashuWallet> getWallet(String mintUrl) async {
    if (_wallets[mintUrl] != null) return _wallets[mintUrl]!;
    final mint = CashuMint(mintUrl);
    final keys = await mint.getKeys();
    final wallet = CashuWallet(mint, keys);
    if (keys != null) {
      setKeys(mintUrl, keys);
    }
    _wallets[mintUrl] = wallet;
    return wallet;
  }

  Future<String?> getCurrentKeySetId(String mintUrl) async {
    final wallet = await getWallet(mintUrl);
    final keys = await wallet.mint.getKeys();
    final keySetId = keys?.deriveKeysetId();
    if (keys != null) {
      setKeys(mintUrl, keys, keySetId);
    }
    return keySetId;
  }
}

extension WalletManagerHandler on WalletManager {

  Future<bool> claimToken(String encodedToken) async {
    encodedToken = CashuTokenHelper.isCashuToken(encodedToken) ?? '';
    print('[Cashu - claimToken] encodedToken: $encodedToken');
    if (encodedToken.trim().isEmpty) return false;

    final decoded = CashuTokenHelper.getDecodedToken(encodedToken);
    print('[Cashu - claimToken] decoded: $decoded');
    if (decoded == null || decoded.token.isEmpty) return false;

    final trustedMints = await MintStore.getMintsUrls();
    print('[Cashu - claimToken] trustedMints: $trustedMints');
    final tokenEntries = decoded.token.where((x) => trustedMints.contains(x.mint)).toList();
    print('[Cashu - claimToken] tokenEntries: $tokenEntries');
    if (tokenEntries.isEmpty) return false;

    final mintUrls = tokenEntries.map((x) => x.mint).where((x) => x.isNotEmpty).toList();
    print('[Cashu - claimToken] mintUrls: $mintUrls');
    if (mintUrls.isEmpty) return false;

    final wallet = await getWallet(mintUrls[0]);
    print('[Cashu - claimToken] wallet: $wallet');
    final response = await wallet.receive(encodedToken: encodedToken);
    print('[Cashu - claimToken] response: $response');
    if (response == null) return false;

    final token = response.token;
    final tokensWithErrors = response.tokensWithErrors;
    final newKeys = response.newKeys;

    if (newKeys != null) {
       setKeys(mintUrls[0], newKeys);
    }

    await CashuTokenHelper.addToken(token);

    if (tokensWithErrors != null) {
      final encodedTokensWithErrors = CashuTokenHelper.getEncodedToken(tokensWithErrors);
      if (await CashuTokenHelper.isTokenSpendable(encodedTokensWithErrors)) {
        print('[claimToken][tokensWithErrors] $tokensWithErrors');
        await CashuTokenHelper.addToken(tokensWithErrors);
      }
    }

    for (final mint in mintUrls) {
      await MintStore.addMint(mint);
    }

    return token.token.isNotEmpty;
  }
}

extension WalletDefaultItemEx on WalletManager {

}