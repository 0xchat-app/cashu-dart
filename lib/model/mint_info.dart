
import 'dart:convert';

import '../business/mint/mint_helper.dart';
import '../utils/database/db.dart';
import '../utils/database/db_object.dart';
import '../utils/tools.dart';

@reflector
class MintInfo extends DBObject {

  MintInfo({
    required String mintURL,
    required this.name,
    required this.pubkey,
    required this.version,
    required this.description,
    required this.descriptionLong,
    required this.contact,
    required this.motd,
    required this.nuts,
  }) : mintURL = MintHelper.getMintURL(mintURL);

  final String mintURL;
  final String name;
  final String pubkey;
  final String version;
  final String description;
  final String descriptionLong;

  final String contactJson = '';
  final List<List<String>> contact;

  final String motd;

  final String nutsJson = '';
  final Map<String, Map<String, dynamic>> nuts;

  factory MintInfo.fromServerMap(Map json, String mintURL) {

    return MintInfo(
      mintURL: mintURL,
      name: Tools.getValueAs(json, 'name', ''),
      pubkey: Tools.getValueAs(json, 'pubkey', ''),
      version: Tools.getValueAs(json, 'version', ''),
      description: Tools.getValueAs(json, 'description', ''),
      descriptionLong: Tools.getValueAs(json, 'description_long', ''),
      contact: Tools.getValueAs(json, 'contact', <List<String>>[]),
      motd: Tools.getValueAs(json, 'motd', ''),
      nuts: Tools.getValueAs(json, 'nuts', <String, Map<String, dynamic>>{}),
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
    'contactJson': contact,
    'motd': motd,
    'nutsJson': nuts,
  };

  static MintInfo fromMap(Map<String, Object?> map) {
    var contact = <List<String>>[];
    var nuts = <String, Map<String, dynamic>>{};

    try {
      contact = json.decode(Tools.getValueAs(map, 'contactJson', ''));
      nuts = json.decode(Tools.getValueAs(map, 'nutsJson', ''));
    } catch(_) {}

    return MintInfo(
      mintURL: Tools.getValueAs(map, 'mintURL', ''),
      name: Tools.getValueAs(map, 'name', ''),
      pubkey: Tools.getValueAs(map, 'pubkey', ''),
      version: Tools.getValueAs(map, 'version', ''),
      description: Tools.getValueAs(map, 'description', ''),
      descriptionLong: Tools.getValueAs(map, 'descriptionLong', ''),
      contact: contact,
      motd: Tools.getValueAs(map, 'motd', ''),
      nuts: nuts,
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