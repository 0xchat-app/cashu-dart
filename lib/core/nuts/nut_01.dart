
import '../../utils/network/http_client.dart';

typedef MintKeys = Map<String, String>;

class Nut1 {
  /// Get the mints public keys
  /// [keysetId] optional param to get the keys for a specific keyset. If not specified, the keys from the active keyset are fetched
  /// Returns the mints public keys
  static Future<MintKeys?> getKeys({required String mintURL, String? keysetId}) async {
    var endpoint = '';
    if (keysetId != null) {
      keysetId = Uri.encodeComponent(keysetId);
      endpoint = '$mintURL/keys/$keysetId';
    } else {
      endpoint = '$mintURL/keys';
    }
    return HTTPClient.get(
      endpoint,
      modelBuilder: (json) {
        if (json is Map) {
          return json.map((key, value) {
            return MapEntry(key.toString(), value.toString());
          }).cast<String, String>();
        } else {
          return null;
        }
      },
    );
  }
}