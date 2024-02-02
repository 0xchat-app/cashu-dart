
import 'package:cashu_dart/business/wallet/cashu_manager.dart';
import 'package:cashu_dart/model/invoice_listener.dart';

import '../../core/nuts/nut_00.dart';
import '../../model/invoice.dart';
import '../../model/mint_model.dart';
import '../../utils/network/response.dart';
import '../cashu_api.dart';
import 'cashu_financial_api.dart';
import 'cashu_mint_api.dart';
import 'cashu_transaction_api.dart';

class CashuAPIV1Client extends CashuAPIClient {

  // Financial
  @override
  int totalBalance() => CashuFinancialAPI.totalBalance();

  @override
  Future<int?> checkProofsAvailable(IMint mint) {
    return CashuFinancialAPI.checkProofsAvailable(mint);
  }

  @override
  Future<List<Proof>> getAllUseProofs(IMint mint) {
    return CashuFinancialAPI.getAllUseProofs(mint);
  }

  // Mint
  @override
  Future<List<IMint>> mintList() => CashuMintAPI.mintList();

  @override
  Future<bool> deleteMint(IMint mint) => CashuMintAPI.deleteMint(mint);

  @override
  Future editMintName(IMint mint, String name) => CashuMintAPI.editMintName(mint, name);

  // Transaction
  @override
  Future<CashuResponse<(String memo, int amount)>> redeemEcash(String ecashString) {
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