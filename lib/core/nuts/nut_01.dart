
import '../../utils/network/http_client.dart';
import '../../utils/tools.dart';
import 'define.dart';

typedef MintKeys = Map<String, String>;

class MintKeysPayload {
  MintKeysPayload(this.id, this.unit, this.keys);
  final String id;
  final String unit;
  final MintKeys keys;

  static MintKeysPayload? fromServerMap(json) {
    final id = Tools.getValueAs(json, 'id', '');
    final unit = Tools.getValueAs(json, 'unit', '');
    final keys = Tools.getValueAs<Map>(json, 'keys', {})
        .map((key, value) => MapEntry(key.toString(), value.toString()));
    if (id.isEmpty || unit.isEmpty || keys.isEmpty) return null;
    return MintKeysPayload(id, unit, keys);
  }

  @override
  String toString() {
    return '${super.toString()}, id: $id, unit: $unit';
  }
}

class Nut1 {
  static Future<List<MintKeysPayload>?> requestKeys({required String mintURL, String? keysetId}) async {
    var endpoint = nutURLJoin(mintURL, 'keys');
    if (keysetId != null) {
      keysetId = Uri.encodeComponent(keysetId);
      endpoint = '$endpoint/$keysetId';
    }
    return HTTPClient.get(
      endpoint,
      modelBuilder: (json) {
        if (json is! Map) return null;
        final keysets = Tools.getValueAs(json, 'keysets', []);
        return keysets.map((e) => MintKeysPayload.fromServerMap(e))
            .where((element) => element != null)
            .cast<MintKeysPayload>()
            .toList();
      },
    );
  }
}