
import 'package:cashu_dart/model/mint_info.dart';

import '../business/mint/mint_helper.dart';
import '../utils/database/db.dart';
import '../utils/database/db_object.dart';
import '../utils/tools.dart';

@reflector
class IMint extends DBObject {

  IMint({
    required String mintURL,
    this.name = '',
  }) : mintURL = MintHelper.getMintURL(mintURL);

  final String mintURL;

  String name;

  /// key: unit, value: keysetId
  final Map<String, String> _keysetIds = {};

  int balance = 0;

  MintInfo? info;

  String? keysetId(String unit) => _keysetIds[unit];
  void updateKeysetId(String keysetId, String unit) {
    if (keysetId.isEmpty) return ;
    _keysetIds[unit] = keysetId;
  }
  void cleanKeysetId() => _keysetIds.clear();

  @override
  Map<String, Object?> toMap() => {
    'mintURL': mintURL,
    'name': name,
  };

  static IMint fromMap(Map<String, Object?> map) =>
      IMint(
        mintURL: map['mintURL']?.typedOrDefault('') ?? '',
        name: map['name']?.typedOrDefault('') ?? '',
      );

  static String? tableName() {
    return "IMint";
  }

  static List<String?> primaryKey() {
    return ['mintURL'];
  }

  static List<String?> ignoreKey() {
    return ['_keysetIds, _balance, info'];
  }
}