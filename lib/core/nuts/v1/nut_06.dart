
import '../../../model/mint_info.dart';
import '../../../utils/network/http_client.dart';
import '../define.dart';

class Nut6 {
  static Future<CashuResponse<MintInfo>> requestMintInfo({
    required String mintURL,
  }) async {
    return HTTPClient.get(
      nutURLJoin(mintURL, 'info'),
      modelBuilder: (json) {
        if (json is! Map) return null;
        return MintInfo.fromServerMap(json, mintURL);
      },
    );
  }
}