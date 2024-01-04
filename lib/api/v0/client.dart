
import '../../core/nuts/nut_00.dart';
import '../../model/history_entry.dart';
import '../../model/invoice.dart';
import '../../model/mint_model.dart';
import '../cashu_api.dart';
import 'cashu_financial_api.dart';
import 'cashu_mint_api.dart';
import 'cashu_transaction_api.dart';

class CashuAPIV0Client implements CashuAPIClient {

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
  }) {
    return CashuTransactionAPI.sendEcash(mint: mint, amount: amount, memo: memo);
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
  Future<IInvoice?> createLightningInvoice({
    required IMint mint,
    required int amount,
    Function()? onSuccess,
  }) {
    return CashuTransactionAPI.createLightningInvoice(
      mint: mint,
      amount: amount,
      onSuccess: onSuccess,
    );
  }
}