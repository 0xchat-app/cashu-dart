
import '../core/nuts/v1/nut_11.dart';

class CashuTokenInfo {
  CashuTokenInfo({
    required this.amount,
    required this.unit,
    required this.memo,
    this.p2pkInfo,
  });
  final int amount;
  final String unit;
  final String memo;
  final CashuTokenP2PKInfo? p2pkInfo;

  @override
  String toString() {
    return '${super.toString()}, amount: $amount, unit: $unit, memo: $memo, p2pkInfo: $p2pkInfo';
  }
}

class CashuTokenP2PKInfo {
  CashuTokenP2PKInfo({
    required this.receivePubKeys,
    this.refundPubKeys,
    this.lockTime,
    this.signNumRequired,
    this.sigFlag,
  });
  List<String> receivePubKeys;
  List<String>? refundPubKeys;
  DateTime? lockTime;
  int? signNumRequired;
  P2PKSecretSigFlag? sigFlag;

  // Timestamp in seconds
  String? get lockTimeTimestamp {
    if (lockTime == null) return null;
    return (lockTime!.millisecondsSinceEpoch ~/ 1000).toString();
  }

  @override
  String toString() {
    return '${super.toString()}, receivePubKeys: $receivePubKeys, '
        'refundPubKeys: $refundPubKeys, '
        'locktime: $lockTime, '
        'signNumRequired: $signNumRequired, '
        'sigFlag: $sigFlag';
  }
}