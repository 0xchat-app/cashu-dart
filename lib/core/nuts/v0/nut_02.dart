
import '../../../model/keyset_info.dart';
import '../../../utils/network/http_client.dart';
import '../../../utils/tools.dart';
import '../define.dart';

class Nut2 {
  static Future<CashuResponse<List<KeysetInfo>>> requestKeysetsState({required String mintURL}) async {
    return HTTPClient.get(
      nutURLJoin(mintURL, 'keysets', version: ''),
      modelBuilder: (json) {
        if (json is! Map) return null;
        final keysets = Tools.getValueAs(json, 'keysets', []);
        return keysets.map((e) => KeysetInfo(
          id: e,
          mintURL: mintURL,
          unit: 'sat',
          active: true,
        )).toList();
      },
    );
  }
}