
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
    this.receivePubKeys,
    this.refundPubKeys,
    this.lockTime,
    this.signNumRequired,
    this.sigFlag,
  });
  List<String>? receivePubKeys;
  List<String>? refundPubKeys;
  String? lockTime;
  String? signNumRequired;
  P2PKSecretSigFlag? sigFlag;

  DateTime? get lockTimeDate {
    final lockTime = int.tryParse(this.lockTime ?? '');
    if (lockTime == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(lockTime * 1000);
  }

  @override
  String toString() {
    return '${super.toString()}, receivePubKeys: $receivePubKeys, '
        'refundPubKeys: $refundPubKeys, '
        'locktime: $lockTime, '
        'lockTimeDate: $lockTimeDate, '
        'signNumRequired: $signNumRequired, '
        'sigFlag: $sigFlag';
  }
}