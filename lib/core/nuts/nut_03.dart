
import '../../utils/network/http_client.dart';
import '../../utils/tools.dart';
import 'define.dart';
import 'nut_00.dart';

class Nut3 {
  static Future<List<BlindedSignature>?> swap({
    required String mintURL,
    required List<Proof> proofs,
    required List<BlindedMessage> outputs,
  }) async {
    return HTTPClient.post(
      nutURLJoin(mintURL, 'swap'),
      params: {
        'inputs': proofs.map((e) {
          return {
            'id': e.id,
            'amount': num.tryParse(e.amount) ?? 0,
            'secret': e.secret,
            'C': e.C,
          };
        }).toList(),
        'outputs': outputs.map((e) {
          return {
            'amount': e.amount,
            'B_': e.B_,
          };
        }).toList(),
      },
      modelBuilder: (json) {
        if (json is! Map) return null;
        final promises = Tools.getValueAs<List>(json, 'promises', []);
        return promises.map((e) {
          if (e is! Map) return null;
          return BlindedSignature.fromServerMap(e);
        }).where((e) => e != null).toList().cast();
      },
    );
  }
}