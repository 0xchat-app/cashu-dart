
import 'dart:convert';

enum ConditionType {

  p2pk('P2PK');

  const ConditionType(this.kind);
  final String kind;

  static ConditionType? fromValue(dynamic value) =>
      ConditionType.values.where(
            (element) => element.kind == value,
      ).firstOrNull;
}

typedef Nut10Data = (ConditionType kind, String nonce, String data, List<List<String>> tags);

abstract mixin class Nut10 {

  ConditionType get type;
  String get nonce;
  String get data;
  List<List<String>> get tags;

  String toSecretString() {
    final entry = [
      type.kind,
      {
        'nonce': nonce,
        'data': data,
        'tags': tags,
      }
    ];
    return jsonEncode(entry);
  }

  static Nut10Data? dataFromSecretString(String secret) {
    try {
      final entry = jsonDecode(secret) as List;
      final kind = ConditionType.fromValue(entry.firstOrNull);

      final map = entry[1];
      final tags = (map['tags'] as List).map(
        (list) => list.map((e) => e.toString()).cast<String>().toList()
      ).cast<List<String>>().toList();
      return (kind!, map['nonce'] as String, map['data'] as String, tags);
    } catch (_) {
      return null;
    }
  }
}