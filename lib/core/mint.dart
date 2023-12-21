
import '../utils/tools.dart';
import '../model/define.dart';

class CashuMint {
  MintKeys _keys;
  String _keySetId = '';
  final String mintURL;

  CashuMint(this.mintURL, [MintKeys? keys])
      : _keys = keys ?? {} {
    if (keys != null) {
      _keySetId = _keys.deriveKeysetId();
    }
  }

  MintKeys get keys => _keys;
  String get keySetId => _keySetId;

  /// Update mint Keys
  void updateKeys(MintKeys keys) {
    _keys = keys;
    _keySetId = _keys.deriveKeysetId();
  }
}