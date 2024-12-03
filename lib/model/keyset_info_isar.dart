
import 'dart:convert';

import 'package:isar/isar.dart';

import '../utils/tools.dart';

part 'keyset_info_isar.g.dart';

@collection
class KeysetInfoIsar {
  KeysetInfoIsar({
    required this.keysetId,
    required this.mintURL,
    required this.unit,
    required this.active,
    this.keysetRaw = '',
    this.inputFeePPK = 0,
  }) : keyset = keysetFromRaw(keysetRaw);

  Id id = Isar.autoIncrement;

  @Index(composite: [CompositeIndex('mintURL')], unique: true)
  String keysetId;
  String mintURL;
  String unit;
  bool active;

  @Ignore()
  Map<String, String> keyset = {};
  int inputFeePPK;

  // for db column
  String keysetRaw = '';

  factory KeysetInfoIsar.fromServerMap(Map jsonMap, String mintURL) {
    return KeysetInfoIsar(
      keysetId: Tools.getValueAs<String>(jsonMap, 'id', ''),
      mintURL: mintURL,
      unit: Tools.getValueAs<String>(jsonMap, 'unit', ''),
      active: Tools.getValueAs(jsonMap, 'active', false),
      inputFeePPK: Tools.getValueAs(jsonMap, 'input_fee_ppk', 0),
    );
  }

  @override
  String toString() {
    return '${super.toString()}, id: $keysetId, unit: $unit, active: $active';
  }

  static Map<String, String> keysetFromRaw(String keysetRaw) {
    try {
      final decoded = json.decode(keysetRaw) as Map;
      return decoded.map((key, value) => MapEntry(key.toString(), value.toString()));
    } catch (_) {
      return {};
    }
  }
}