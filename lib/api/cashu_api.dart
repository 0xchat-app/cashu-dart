
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cashu_dart/business/history/hitstory_store.dart';
import 'package:cashu_dart/business/mint/mint_store.dart';
import 'package:cashu_dart/business/proof/proof_store.dart';
import 'package:cashu_dart/core/nuts/DHKE.dart';
import 'package:cashu_dart/core/nuts/nut_01.dart';
import 'package:cashu_dart/core/nuts/nut_03.dart';
import 'package:cashu_dart/core/nuts/nut_04.dart';
import 'package:cashu_dart/core/nuts/nut_06.dart';
import 'package:cashu_dart/model/history_entry.dart';
import 'package:cashu_dart/utils/tools.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';

import '../business/proof/proof_store_helper.dart';
import '../business/wallet/wallet_manager.dart';
import '../core/cashu_helper.dart';
import '../core/nuts/nut_00.dart';
import '../core/nuts/nut_02.dart';
import '../core/nuts/nut_05.dart';
import '../model/mint_model.dart';
import '../utils/cashu_token_helper.dart';

class CashuAPI {

  static test() async {
    // const mint = 'https://legend.lnbits.com/cashu/api/v1/AptDNABNBXv8gpuywhx6NV';
    const mint = 'https://testnut.cashu.space';
    // const mint = 'https://mint.tangjinxing.com';

    const amount = 8;

    var hash = 'Ldaa6xB81bhUHYyES-EgGhsZ6_sTkJINjv_9hINe';
    var pr = 'lnbc80n1pjc9guhsp5rvv0v5dy4nruqnflhx27mqrqes64xp47u4gq6c89dp2kzxrzpm3qpp50f8lykw5vppgvluj9evv8tfkd0pejpk3zudulz5rsr0q98mz86sqdq4gdshx6r4ypjx2ur0wd5hgxqzjccqpjrzjq0rlz0ft303xlj642d3lj3vakvza269hdqle7llxv2p034ns4mjawzel0sqqtjsqqyqqqqqqqqqqraqq9q9qxpqysgqza0td7x55xqj6z0eyv8yfvendv07t2lrury5kfhxx4xsufuhpzz9y6hlv4n934550qzhqe6j3ls60rrrmnm84nat75a329s4t0a6wggqwk48tr';

    // print('zhw=================>${await Nut1.requestKeys(mintURL: mint)}');
    // print('zhw=================>${await Nut2.requestKeysetsState(mintURL: mint)}');
    final quoteInfo = await Nut4.requestMintQuote(mintURL: mint, amount: amount);
    print('zhw=================>$quoteInfo');
    final quote = quoteInfo?.quote ?? '';
    final proofs = await CashuHelper.requestTokensFromMint(
      mint: IMint(mintURL: mint),
      amount: amount,
      quoteID: quote,
    );
    print('zhw=================>$proofs');

    // Nut3.swap(mintURL: mint, proofs: proofs, outputs: outputs)
  }

  static Future<List<IMint>> localMintList() {
    return MintStore.getMints();
  }

  static setDefaultMint(IMint mint) {
    WalletManager.shared.defaultMint = mint;
  }

  // static Future<String?> sendToken({
  //   String? mintURL,
  //   required int amount,
  //   String memo = '',
  //   List<Proof> proofs = const [],
  // }) async {
  //   await WalletManager.shared.setupFinish.future;
  //
  //   mintURL ??= WalletManager.shared.defaultMint.mintURL;
  //   final wallet = await WalletManager.shared.getWallet(mintURL);
  //   if (proofs.isEmpty) {
  //     proofs = await ProofStoreHelper.getProofsToUse(mintURL: mintURL, amount: amount);
  //   }
  //
  //   final sendResult = await wallet.send(amount: amount, proofs: proofs);
  //   if (sendResult == null) return null;
  //
  //   final send = sendResult.send;
  //   final returnChange = sendResult.returnChange;
  //   final newKeys = sendResult.newKeys;
  //
  //   if (newKeys != null) {
  //     WalletManager.shared.setKeys(mintURL, newKeys);
  //   }
  //
  //   if (returnChange.isNotEmpty) {
  //     await CashuTokenHelper.addToken(Token(token: [TokenEntry(mint: mintURL, proofs: returnChange)]));
  //   }
  //
  //   await ProofStore.deleteProofs(proofs);
  //   return CashuTokenHelper.getEncodedToken(
  //     Token(
  //       token: [TokenEntry(mint: mintURL, proofs: send)],
  //       memo: memo.isNotEmpty ? memo : 'Sent via eNuts.',
  //     ),
  //   );
  // }
  //
  // /// An token info model is returned, or null on failed
  // static Future<TokenInfo?> receiveToken(String encodedToken) async {
  //   await WalletManager.shared.setupFinish.future;
  //
  //   print('[Cashu - receiveToken] encodedToken: $encodedToken');
  //   bool success = await WalletManager.shared.claimToken(encodedToken);
  //   if (!success) return null;
  //
  //   print('[Cashu - receiveToken] success: $success');
  //   final info = CashuTokenHelper.getTokenInfo(encodedToken);
  //   if (info == null) return null;
  //
  //   print('[Cashu - receiveToken] info: $info');
  //   await HistoryStore.addToHistory(
  //     amount: info.value,
  //     type: IHistoryType.eCash,
  //     value: encodedToken,
  //     mints: info.mints,
  //   );
  //
  //   return info;
  // }
}