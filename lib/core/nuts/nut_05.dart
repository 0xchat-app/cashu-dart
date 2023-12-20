
import '../../utils/network/http_client.dart';
import '../../utils/tools.dart';

class Nut5 {
  /// Estimate fees for a given LN invoice
  /// Returns estimated Fee
  static Future<int?> checkingLightningFees({
    required String mintURL,
    required String pr,
  }) async {
    return HTTPClient.post(
      '$mintURL/checkfees',
      params: {'pr': pr},
      modelBuilder: (json) {
        if (json is! Map) return null;
        final fee = Tools.getValueAs<int?>(json, 'fee', null);
        return fee;
      },
    );
  }
}