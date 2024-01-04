
import '../utils/database/db.dart';
import '../utils/database/db_object.dart';
import '../utils/tools.dart';
import 'invoice.dart';

@reflector
class LightningInvoice extends DBObject implements Receipt {
  LightningInvoice({
    required this.pr,
    required this.hash,
    required this.amount,
    required this.mintURL
  });

  final String pr;
  final String hash;

  @override
  final String amount;

  @override
  final String mintURL;

  static LightningInvoice? fromServerMap(Map json, String mintURL, String amount) {
    final pr = Tools.getValueAs<String>(json, 'pr', '');
    final hash = Tools.getValueAs<String>(json, 'hash', '');
    if (pr.isEmpty || hash.isEmpty) return null;
    return LightningInvoice(
      pr: pr,
      hash: hash,
      amount: amount,
      mintURL: mintURL,
    );
  }

  @override
  String toString() {
    return '${super.toString()}, pr: $pr, hash: $hash, mintURL: $mintURL';
  }

  @override
  Map<String, Object?> toMap() => {
    'pr': pr,
    'hash': hash,
    'amount': amount,
    'mintURL': mintURL,
  };

  static LightningInvoice fromMap(Map<String, Object?> map) {
    return LightningInvoice(
      pr: Tools.getValueAs(map, 'pr', ''),
      hash: Tools.getValueAs(map, 'hash', ''),
      amount: Tools.getValueAs(map, 'amount', ''),
      mintURL: Tools.getValueAs(map, 'mintURL', ''),
    );
  }

  static String? tableName() {
    return "LightningInvoice";
  }

  //primaryKey
  static List<String?> primaryKey() {
    return ['mintURL', 'hash'];
  }

  static List<String?> ignoreKey() {
    return [];
  }

  @override
  String get paymentKey => pr;

  @override
  String get redemptionKey => hash;

  @override
  bool get isExpired {
    return false;
  }

  @override
  String get request => pr;

  @override
  int get expiry => 0;
}