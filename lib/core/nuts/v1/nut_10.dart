
import 'dart:convert';

enum ConditionType {

  p2pk('P2PK');

  const ConditionType(this.kind);
  final String kind;
}

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
}