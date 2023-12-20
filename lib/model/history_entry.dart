
import '../utils/database/db.dart';
import '../utils/database/db_object.dart';
import '../utils/tools.dart';

enum IHistoryType {
  unknown(0),
  eCash(1),
  lnInvoice(2),
  multiMintSwap(3);

  final int value;

  const IHistoryType(this.value);

  static IHistoryType fromValue(dynamic value) =>
      IHistoryType.values.where(
        (element) => element.value == value,
      ).firstOrNull ?? IHistoryType.unknown;
}

@reflector
class IHistoryEntry extends DBObject {

  IHistoryEntry({
    required this.amount,
    required this.type,
    required this.timestamp,
    required this.value,
    required this.mints,
    this.sender,
    this.recipient,
    this.preImage,
    this.fee,
    this.isSpent,
  }) : mintsString = mints.join(','),
       typePlain = type.value;

  final num amount;

  final int typePlain;
  final IHistoryType type;

  final double timestamp;

  /// Lightning invoice or encoded Cashu token
  final String value;

  /// mints involved
  final String mintsString;
  final List<String> mints;

  /// sender (nostr username)
  final String? sender;

  /// recipient (nostr username)
  final String? recipient;

  final String? preImage;

  final num? fee;

  /// is token spendable
  final bool? isSpent;

  @override
  Map<String, Object?> toMap() => {
    'amount': amount,
    'typePlain': typePlain,
    'timestamp': timestamp,
    'value': value,
    'mintsString': mintsString,
    'sender': sender,
    'recipient': recipient,
    'preImage': preImage,
    'fee': fee,
    'isSpent': isSpent,
  };

  static IHistoryEntry fromMap(Map<String, Object?> map) {
    final amount = map['amount']?.typedOrDefault(0) ?? 0;
    final type = IHistoryType.fromValue(map['typePlain']);
    final timestamp = map['timestamp']?.typedOrDefault(0.0) ?? 0.0;
    final value = map['value']?.typedOrDefault('') ?? '';
    final mintsString = map['mintsString']?.typedOrDefault('') ?? '';
    final sender = map['sender'] as String?;
    final recipient = map['recipient'] as String?;
    final preImage = map['preImage'] as String?;
    final fee = map['fee'] as num?;
    final isSpent = map['isSpent'] as bool?;

    return IHistoryEntry(
      amount: amount,
      type: type,
      timestamp: timestamp,
      value: value,
      mints: mintsString.split(','),
      sender: sender,
      recipient: recipient,
      preImage: preImage,
      fee: fee,
      isSpent: isSpent,
    );
  }

  static String? tableName() {
    return "IHistoryEntry";
  }

  //primaryKey
  static List<String?> primaryKey() {
    return ['value', 'timestamp'];
  }

  static List<String?> ignoreKey() {
    return ['mints', 'type'];
  }
}