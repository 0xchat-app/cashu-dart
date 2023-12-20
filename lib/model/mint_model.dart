
import '../utils/database/db.dart';
import '../utils/database/db_object.dart';
import '../utils/tools.dart';

@reflector
class IMint extends DBObject {

  IMint({required this.id, required this.mintURL, this.name = ''});

  final String id;
  final String mintURL;
  final String name;

  @override
  Map<String, Object?> toMap() => {
    'id': id,
    'mintURL': mintURL,
    'name': name,
  };

  static IMint fromMap(Map<String, Object?> map) =>
      IMint(
        id: map['id']?.typedOrDefault('') ?? '',
        mintURL: map['mintURL']?.typedOrDefault('') ?? '',
        name: map['name']?.typedOrDefault('') ?? '',
      );

  static String? tableName() {
    return "IMint";
  }

  //primaryKey
  static List<String?> primaryKey() {
    return ['id'];
  }
}