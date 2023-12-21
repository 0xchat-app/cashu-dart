
import 'dart:convert';

import '../utils/database/db.dart';
import '../utils/database/db_object.dart';
import '../utils/tools.dart';

@reflector
class KeysetInfo extends DBObject {
  KeysetInfo({
    required this.id,
    required this.mintURL,
    required this.unit,
    required this.active,
    Map<String, String>? keyset,
  }) : keyset = keyset ?? {};

  String id;
  String mintURL;
  String unit;
  bool active;
  Map<String, String> keyset = {};

  String get keysetRaw => json.encode(keyset);
  set keysetRaw(value) {
    try {
      keyset = json.decode(value);
    } catch(_) {}
  }

  factory KeysetInfo.fromServerMap(Map json, String mintURL) =>
      KeysetInfo(
        id: Tools.getValueAs<String>(json, 'id', ''),
        mintURL: mintURL,
        unit: Tools.getValueAs<String>(json, 'unit', ''),
        active: Tools.getValueAs<bool>(json, 'active', false),
      );

  @override
  String toString() {
    return '${super.toString()}, id: $id, unit: $unit, active: $active';
  }

  @override
  Map<String, Object?> toMap() => {
    'id': id,
    'mintURL': mintURL,
    'unit': unit,
    'active': active,
    'keysetRaw': keysetRaw,
  };

  static KeysetInfo fromMap(Map<String, Object?> map) {
    Map<String, String> keyset = {};
    try {
      keyset = json.decode( Tools.getValueAs(map, 'keysetRaw', ''));
    } catch (_) {}

    return KeysetInfo(
      id: Tools.getValueAs(map, 'id', ''),
      mintURL: Tools.getValueAs(map, 'mintURL', ''),
      unit: Tools.getValueAs(map, 'unit', ''),
      active: Tools.getValueAs(map, 'active', false),
      keyset: keyset,
    );
  }

  static String? tableName() {
    return "KeysetInfo";
  }

  static List<String?> primaryKey() {
    return ['id', 'mintURL'];
  }

  static List<String?> ignoreKey() {
    return ['keyset'];
  }
}