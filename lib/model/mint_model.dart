
import '../business/mint/mint_helper.dart';
import '../utils/database/db.dart';
import '../utils/database/db_object.dart';
import '../utils/tools.dart';
import 'mint_info.dart';

@reflector
class IMint extends DBObject {

  IMint({
    required String mintURL,
    this.name = '',
    this.balance = 0,
  }) : mintURL = MintHelper.getMintURL(mintURL);

  final String mintURL;

  String name;

  /// key: unit, value: keysetId
  final Map<String, String> _keysetIds = {};

  int balance;

  MintInfo? info;

  String? keysetId(String unit) => _keysetIds[unit];
  void updateKeysetId(String keysetId, String unit) {
    if (keysetId.isEmpty) return ;
    _keysetIds[unit] = keysetId;
  }
  void cleanKeysetId() => _keysetIds.clear();

  @override
  String toString() {
    return '${super.toString()}, url: $mintURL, balance: $balance, info: $info';
  }

  @override
  Map<String, Object?> toMap() => {
    'mintURL': mintURL,
    'name': name,
    'balance': balance,
  };

  static IMint fromMap(Map<String, Object?> map) =>
      IMint(
        mintURL: Tools.getValueAs(map, 'mintURL', ''),
        name: Tools.getValueAs(map, 'name', ''),
        balance: Tools.getValueAs(map, 'balance', 0)
      );

  static String? tableName() {
    return "IMint";
  }

  static List<String?> primaryKey() {
    return ['mintURL'];
  }

  static List<String?> ignoreKey() {
    return ['_keysetIds, info'];
  }
}