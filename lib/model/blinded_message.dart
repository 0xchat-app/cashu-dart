
import 'package:cashu_dart/utils/tools.dart';

class SerializedBlindedMessage {

  SerializedBlindedMessage({
    required this.amount,
    required this.B_,
  });

  final num amount;
  final String B_;

  factory SerializedBlindedMessage.fromServerMap(Map json) =>
      SerializedBlindedMessage(
        amount: json['amount']?.typedOrDefault(0) ?? 0,
        B_: json['B_']?.typedOrDefault('') ?? '',
      );

  Map<String, String> toJson() => {
    'amount': amount.toString(),
    'B_': B_,
  };
}