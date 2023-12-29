
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
  }

  static setDefaultMint(IMint mint) {
    CashuManager.shared.defaultMint = mint;
  }
}