
import 'package:cashu_dart/business/wallet/cashu_manager.dart';
import 'package:cashu_dart/model/invoice_listener.dart';

import '../../business/proof/token_helper.dart';
import '../../core/nuts/nut_00.dart';
import '../../model/history_entry.dart';
import '../../model/invoice.dart';
import '../../model/mint_model.dart';
import '../cashu_api.dart';
import 'cashu_financial_api.dart';
import 'cashu_mint_api.dart';
import 'cashu_transaction_api.dart';

class CashuAPIV1Client extends CashuAPIClient {

  static test() async {
    // const mint = 'https://legend.lnbits.com/cashu/api/v1/AptDNABNBXv8gpuywhx6NV';
    // const mint = 'https://testnut.cashu.space';
    // const mint = 'https://mint.tangjinxing.com';
  }

  // Financial
  @override
  int totalBalance() => CashuFinancialAPI.totalBalance();

  @override
  Future<List<IHistoryEntry>> getHistoryList({
    int size = 10,
    String lastHistoryId = '',
  }) {
    return CashuFinancialAPI.getHistoryList(
      size: size,
      lastHistoryId: lastHistoryId,
    );
  }

  @override
  Future<int?> checkProofsAvailable(IMint mint) {
    return CashuFinancialAPI.checkProofsAvailable(mint);
  }

  @override
  Future<List<Proof>> getAllUseProofs(IMint mint) {
    return CashuFinancialAPI.getAllUseProofs(mint);
  }

  @override
  Future<bool?> checkEcashSpentState(String ecashToken) {
    return TokenHelper.isTokenSpendable(ecashToken);
  }

  // Mint
  @override
  List<IMint> mintList() => CashuMintAPI.mintList();

  @override
  Future<IMint?> addMint(String mintURL) => CashuMintAPI.addMint(mintURL);

  @override
  Future<bool> deleteMint(IMint mint) => CashuMintAPI.deleteMint(mint);

  @override
  Future editMintName(IMint mint, String name) => CashuMintAPI.editMintName(mint, name);

  // Transaction
  @override
  Future<String?> sendEcash({
    required IMint mint,
    required int amount,
    String memo = '',
    List<Proof>? proofs,
  }) {
    return CashuTransactionAPI.sendEcash(
      mint: mint,
      amount: amount,
      memo: memo,
      proofs: proofs,
    );
  }

  @override
  Future<(String memo, int amount)?> redeemEcash(String ecashString) {
    return CashuTransactionAPI.redeemEcash(ecashString);
  }

  @override
  Future<bool> payingLightningInvoice({
    required IMint mint,
    required String pr,
  }) {
    return CashuTransactionAPI.payingLightningInvoice(mint: mint, pr: pr);
  }

  @override
  Future<Receipt?> createLightningInvoice({
    required IMint mint,
    required int amount,
  }) {
    return CashuTransactionAPI.createLightningInvoice(
      mint: mint,
      amount: amount,
    );
  }

  @override
  void addInvoiceListener(CashuListener listener) {
    CashuManager.shared.addListener(listener);
  }

  @override
  void removeInvoiceListener(CashuListener listener) {
    CashuManager.shared.removeListener(listener);
  }
}