
import '../../../utils/network/http_client.dart';
import '../../../utils/tools.dart';
import '../define.dart';
import '../nut_00.dart';
import '../../../utils/network/http_client.dart';
import '../../../utils/tools.dart';
import '../define.dart';
import '../nut_00.dart';

typedef MeltResponse = (
  bool paid,
  String preimage,
  List<BlindedSignature> change,
);

class Nut8 {
  /// Ask mint to perform a melt operation.
  /// This pays a lightning invoice and destroys tokens matching its amount + fees
  static Future<MeltResponse?> payingTheInvoice({
    required String mintURL,
    required String pr,
    required List<Proof> proofs,
    required List<BlindedMessage> outputs,
  }) async {
    return HTTPClient.post(
      '$mintURL/melt',
      params: {
        'proofs': proofs.map((e) {
          return {
            'id': e.id,
            'amount': num.tryParse(e.amount) ?? 0,
            'secret': e.secret,
            'C': e.C,
          };
        }).toList(),
        'outputs': outputs.map((e) {
          return {
            'id': e.id,
            'amount': e.amount,
            'B_': e.B_,
          };
        }).toList(),
        'pr': pr,
      },
      modelBuilder: (json) {
        if (json is! Map) return null;
        final paid = Tools.getValueAs<bool>(json, 'paid', false);
        final preimage = Tools.getValueAs<String>(json, 'preimage', '');
        final change = Tools.getValueAs<List>(json, 'change', []).map((map) {
          if (map is! Map) return null;
          return BlindedSignature.fromServerMap(map);
        }).where((e) => e != null).cast<BlindedSignature>().toList();
        return (paid, preimage, change);
      },
    );
  }

}