

import '../../../model/mint_info.dart';
import '../../../utils/network/http_client.dart';
import '../define.dart';

class Nut9 {
  static Future<CashuResponse<MintInfo>> requestMintInfo({
    required String mintURL,
  }) async {
    return HTTPClient.get(
      nutURLJoin(mintURL, 'info', version: ''),
      modelBuilder: (json) {
        if (json is! Map) return null;
        return MintInfo.fromServerMap(json, mintURL);
      },
    );
  }
}