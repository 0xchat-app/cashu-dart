
import '../utils/database/db.dart';
import '../utils/database/db_object.dart';
import '../utils/tools.dart';

@reflector
class IMint extends DBObject {

  IMint({required this.mintURL, this.name = ''});

  final String mintURL;

  final String name;

  /// key: unit, value: keysetId
  final Map<String, String> keysetIds = {};

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
    return ['id'];
  }

  static List<String?> ignoreKey() {
    return ['keysetIds'];
  }
}