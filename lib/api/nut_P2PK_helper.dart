
import '../core/nuts/v1/nut_11.dart';
import '../utils/tools.dart';

class NutP2PKHelper {
  static String getLockTimeWithSecret(List secret) {
    if (secret.firstOrNull == 'P2PK' && secret.length >= 2) {
      Map data = secret[1] ?? {};
      final tags = Tools.getValueAs(data, 'tags', []);
      for (final tag in tags) {
        if (tag is List && tag.length >= 2) {
          if (tag.first == P2PKSecretTagKey.lockTime.name) {
            return tag[1];
          }
        }
      }
    }
    return '';
  }
}