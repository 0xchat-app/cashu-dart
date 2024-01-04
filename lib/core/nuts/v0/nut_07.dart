
import '../../../utils/network/http_client.dart';
import '../../../utils/tools.dart';
import '../define.dart';
import '../nut_00.dart';

enum TokenState {
  live,
  burned,
  inFlight,
}

extension TokenStateEx on TokenState {
  static TokenState fromState(bool spendable, bool pending) {
    if (!spendable) return TokenState.burned;
    if (!pending) {
      return TokenState.live;
    } else {
      return TokenState.inFlight;
    }
  }
}

class Nut7 {

}