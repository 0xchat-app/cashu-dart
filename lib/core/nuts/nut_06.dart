
import '../../model/mint_info.dart';
import '../../utils/network/http_client.dart';
import 'define.dart';

class Nut6 {
  static Future<MintInfo?> requestMintInfo({
    required String mintURL,
  }) async {
    return HTTPClient.post(
      nutURLJoin(mintURL, 'info'),
      modelBuilder: (json) {
        if (json is! Map) return null;
        return MintInfo.fromServerMap(json);
      },
    );
  }
}