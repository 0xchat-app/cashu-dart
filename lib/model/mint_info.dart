
import 'dart:convert';

import '../business/mint/mint_helper.dart';
import '../utils/database/db.dart';
import '../utils/database/db_object.dart';
import '../utils/tools.dart';

class NutsSupportInfo {
  NutsSupportInfo({
    required this.nutNum,
    this.methods = const [],
    this.supported = true,
    this.disabled = false,
  });

  static Set<int> get mandatoryNut => {0, 1, 2, 3, 4, 5, 6};

  final int nutNum;
  final List<List<String>> methods;
  final bool supported;
  final bool disabled;

  factory NutsSupportInfo.fromServerJson(String nutNum, Map json) {
    final methods = <List<String>>[];
    final methodsRaw = json['methods'];
    if (methodsRaw is List) {
      final methodList = [...methodsRaw];
      for (var method in methodList) {
        if (method is List) {
          final list = [...method];
          final target = list.map((e) => e.toString()).toList();
          methods.add(target);
        }
      }
    }

    final supported = Tools.getValueAs(json, 'supported', true);
    final disabled = Tools.getValueAs(json, 'disabled', false);

    return NutsSupportInfo(
      nutNum: int.tryParse(nutNum) ?? 0,
      methods: methods,
      supported: supported,
      disabled: disabled,
    );
  }

  @override
  String toString() {
    return '${super.toString()}, nutNum: $nutNum, methods: $methods, supported: $supported, disabled: $disabled';
  }
}

@reflector
class MintInfo extends DBObject {

  MintInfo({
    required String mintURL,
    required this.name,
    required this.pubkey,
    required this.version,
    required this.description,
    required this.descriptionLong,
    List contactRaw = const [],
    required this.motd,
    Map nutsRaw = const {},
  }) : mintURL = MintHelper.getMintURL(mintURL) {

    // Contact
    for (var entry in contactRaw) {
      if (entry is List && entry.length > 1) {
        contact.add(entry.map((e) => e.toString()).toList());
      }
    }

    // Nuts
    nutsRaw.forEach((key, value) {
      if (value is Map) {
        nuts[key.toString()] = value;
      }
    });
    nuts.forEach((key, value) {
      nutsInfo.add(NutsSupportInfo.fromServerJson(key, value));
    });
    nutsInfo.sort((a, b) => a.nutNum - b.nutNum);
  }

  final String mintURL;
  final String name;
  final String pubkey;
  final String version;
  final String description;
  final String descriptionLong;

  final String contactJson = '';
  List<List<String>> contact = [];

  final String motd;

  final String nutsJson = '';
  Map<String, Map> nuts = {};
  List<NutsSupportInfo> nutsInfo = [];

  factory MintInfo.fromServerMap(Map json, String mintURL) {
    var nuts = {};
    final nutsRaw = json['nuts'];
    if (nutsRaw is Map) {
      nuts = nutsRaw;
    } else if (nutsRaw is List) {
      nuts = nutsRaw.fold(<String, Map<String, dynamic>>{}, (pre, e) {
        pre[e] = {};
        return pre;
      });
    }

    return MintInfo(
      mintURL: mintURL,
      name: Tools.getValueAs(json, 'name', ''),
      pubkey: Tools.getValueAs(json, 'pubkey', ''),
      version: Tools.getValueAs(json, 'version', ''),
      description: Tools.getValueAs(json, 'description', ''),
      descriptionLong: Tools.getValueAs(json, 'description_long', ''),
      contactRaw: Tools.getValueAs(json, 'contact', []),
      motd: Tools.getValueAs(json, 'motd', ''),
      nutsRaw: nuts,
    );
  }


  @override
  String toString() {
    return '${super.toString()}, name: $name, pubkey: $pubkey, version: $version';
  }

  @override
  Map<String, Object?> toMap() => {
    'mintURL': mintURL,
    'name': name,
    'pubkey': pubkey,
    'version': version,
    'description': description,
    'descriptionLong': descriptionLong,
    'contactJson': json.encode(contact),
    'motd': motd,
    'nutsJson': json.encode(nuts),
  };

  static MintInfo fromMap(Map<String, Object?> map) {
    var contactRaw = [];
    var nutsRaw = {};

    try {
      contactRaw = json.decode(Tools.getValueAs(map, 'contactJson', ''));
      nutsRaw = json.decode(Tools.getValueAs(map, 'nutsJson', ''));
    } catch(_) { }

    return MintInfo(
      mintURL: Tools.getValueAs(map, 'mintURL', ''),
      name: Tools.getValueAs(map, 'name', ''),
      pubkey: Tools.getValueAs(map, 'pubkey', ''),
      version: Tools.getValueAs(map, 'version', ''),
      description: Tools.getValueAs(map, 'description', ''),
      descriptionLong: Tools.getValueAs(map, 'descriptionLong', ''),
      contactRaw: contactRaw,
      motd: Tools.getValueAs(map, 'motd', ''),
      nutsRaw: nutsRaw,
    );
  }

  static String? tableName() {
    return "MintInfo";
  }

  static List<String?> primaryKey() {
    return ['mintURL'];
  }

  static List<String?> ignoreKey() {
    return ['contact, nuts'];
  }
}