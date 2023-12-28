
import 'dart:async';

import 'package:cashu_dart/business/proof/proof_helper.dart';
import 'package:cashu_dart/business/transaction/transaction_helper.dart';

import '../business/wallet/cashu_manager.dart';
import '../core/nuts/nut_00.dart';
import '../core/nuts/nut_02.dart';
import '../core/nuts/nut_04.dart';
import '../core/nuts/nut_05.dart';
import '../model/mint_model.dart';

class CashuAPI {

  static test() async {

    // const mint = 'https://legend.lnbits.com/cashu/api/v1/AptDNABNBXv8gpuywhx6NV';
    const mint = 'https://testnut.cashu.space';
    // const mint = 'https://mint.tangjinxing.com';

    const amount = 8;

    var hash = 'Ldaa6xB81bhUHYyES-EgGhsZ6_sTkJINjv_9hINe';
    var pr = 'lnbc80n1pjc9guhsp5rvv0v5dy4nruqnflhx27mqrqes64xp47u4gq6c89dp2kzxrzpm3qpp50f8lykw5vppgvluj9evv8tfkd0pejpk3zudulz5rsr0q98mz86sqdq4gdshx6r4ypjx2ur0wd5hgxqzjccqpjrzjq0rlz0ft303xlj642d3lj3vakvza269hdqle7llxv2p034ns4mjawzel0sqqtjsqqyqqqqqqqqqqraqq9q9qxpqysgqza0td7x55xqj6z0eyv8yfvendv07t2lrury5kfhxx4xsufuhpzz9y6hlv4n934550qzhqe6j3ls60rrrmnm84nat75a329s4t0a6wggqwk48tr';

    // 1
    // print('zhw=================>${await Nut1.requestKeys(mintURL: mint)}');

    // 2
    // print('zhw=================>${await Nut2.requestKeysetsState(mintURL: mint)}');

    // 4
    // var quoteInfo = await Nut4.requestMintQuote(mintURL: mint, amount: amount);
    // print('zhw=================>$quoteInfo');
    // final quote = quoteInfo?.quote ?? '';
    // var proofs = await TransactionHelper.requestTokensFromMint(
    //   mint: IMint(mintURL: mint),
    //   amount: amount,
    //   quoteID: quote,
    // );
    // print('zhw=================>proofs: $proofs');

    // 3
    // proofs = await CashuHelper.swapProofs(
    //   mint: IMint(mintURL: mint),
    //   proofs: proofs!,
    // );
    // print('zhw=================>new proofs: $proofs');

    // 5
    // final quoteInfo = await Nut4.requestMintQuote(mintURL: mint, amount: amount);
    // final result = await Nut5.requestMeltQuote(mintURL: mint, request: quoteInfo!.request);
    // print('zhw=================>result: $result');

    // 6
    // print('zhw=================>${await Nut6.requestMintInfo(mintURL: mint)}');

    // 7
    // print('zhw=================>${await Nut7.requestTokenState(mintURL: mint, proofs: proofs!)}');

    // 8
    // quoteInfo = await Nut4.requestMintQuote(mintURL: mint, amount: amount);
    // await CashuHelper.payingTheQuote(
    //   mint: IMint(mintURL: mint),
    //   quoteID: quoteInfo!.quote,
    //   proofs: proofs!,
    //   fee: 0,
    // );

    // Nut3.swap(mintURL: mint, proofs: proofs, outputs: outputs)
  }

  static setDefaultMint(IMint mint) {
    CashuManager.shared.defaultMint = mint;
  }

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