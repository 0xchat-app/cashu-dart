
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
import 'package:cashu_dart/core/wallet.dart';
import 'package:cashu_dart/model/history_entry.dart';
import 'package:cashu_dart/utils/tools.dart';

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
    // const mint = 'https://testnut.cashu.space';
    const mint = 'https://mint.tangjinxing.com';

    const amount = 8;

    var hash = 'uV24oe4OPsbKDNnx_4Gs9DB5QaL9OB9GwDEUsTwj';
    var pr = 'lnbc80n1pjcz4eqsp5jlttpuukequamn66k5yp5t268yyx6frywg0tshz6aun9lpk8tx7qpp5w27hyee0k0cxrhnlzt4dmj8jergy5jtc97rm4fk9knq23x4ycekqdq4gdshx6r4ypjx2ur0wd5hgxqzjccqpjrzjqwkf0wuqadvvmfuq5vqnq99q8qgkk8mn4zuxfc3uuykcsrjhj5pp7zchcuqqvscqqyqqqqqqqqqqqssq9q9qxpqysgqll8yjp90jep0szzzxgjyrxuprytvjwv6nu0c8v7nr24l0lntmq4jf5sppvmm5uk7gssr2ny3ey40awef896ekcmu6xwe3c7j8z2gndgqkccyqv';

    // # Test 1
    // mint private key: 0000000000000000000000000000000000000000000000000000000000000001
    // x: "test_message"
    // r: 0000000000000000000000000000000000000000000000000000000000000001 # hex encoded
    // B_: 02a9acc1e48c25eeeb9289b5031cc57da9fe72f3fe2861d264bdc074209b107ba2
    // C_: 02a9acc1e48c25eeeb9289b5031cc57da9fe72f3fe2861d264bdc074209b107ba2

    // final secret = 'test_message'.asBytes();
    // final k = BigInt.parse('0000000000000000000000000000000000000000000000000000000000000001', radix: 16);
    // final r = BigInt.parse('0000000000000000000000000000000000000000000000000000000000000001', radix: 16);
    // final (B_, r1) = DHKE.blindMessage(secret, r);
    // // final C = DHKE.unblinding('02a9acc1e48c25eeeb9289b5031cc57da9fe72f3fe2861d264bdc074209b107ba2', r, K);
    // final Y = DHKE.hashToCurve(secret);
    // final kY = Y * k;
    // final kYHex = DHKE.ecPointToHex(kY!);
    //
    // print('zhw==================>B_: $B_');
    // print('zhw==================>kYHex: $kYHex');

    // C_hex: 02a1b31f77f54fdcbfb34dfa1c033d27688957234784e2a23c25a9516d8519f1ff
    // r: 16863800887508975808622723758543050731680603100263938423696807071558323865712
    // K: 036d83948e3621ce30faf1d0792fa1473cf030b4b0766bfda5a279242092985329

    // secret: Gh4LAhoODA0DGAoVHx8WBh4XGwcDAQIGDRMaGBoNBgQ=
    // C(error): 03e753437dd2c501c91bbf422832d1e692c235252eea0d209d5a8d36e23ec629bf
    // C(expect): 03ba31cad67cd727d9a86759a41dca12ec353b80666787c3cc8084c3ce16244e03



    // final invoice = await Nut3.requestMintInvoice(mintURL: mint, amount: amount);
    // hash = invoice?.hashValue ?? hash;
    // pr = invoice?.pr ?? pr;
    // print('zhw===========>hash: $hash');
    // print('zhw===========>pr: ${invoice?.pr}');
    // //
    // var proofs = await CashuHelper.requestTokensFromMint(
    //   mintURL: mint,
    //   amount: amount,
    //   hash: hash,
    // ) ?? [];
    // print('zhw===========>proofs11: $proofs');


    // pay for ln invoice
    // final newInvoice = await Nut3.requestMintInvoice(mintURL: mint, amount: amount - 50);
    // final newHash = newInvoice?.hashValue ?? '';
    // final newPr = newInvoice?.pr ?? '';
    //
    // final result = await CashuHelper.payingTheInvoice(
    //   mintURL: mint,
    //   pr: newPr,
    //   proofs: proofs ?? [],
    //   feeReserve: 3,
    // );
    // print('zhw==============>$result');


    // splite
    var proofs = [
      Proof(
        id: '8wktXIto+zu/',
        amount: '8',
        secret: 'Gh4LAhoODA0DGAoVHx8WBh4XGwcDAQIGDRMaGBoNBgQ=',
        C: '03e753437dd2c501c91bbf422832d1e692c235252eea0d209d5a8d36e23ec629bf',
      )];
    proofs = await CashuHelper.splitProofs(mintURL: mint, proofs: proofs, supportAmount: 4);
    print('zhw===========>proofs22: $proofs');
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