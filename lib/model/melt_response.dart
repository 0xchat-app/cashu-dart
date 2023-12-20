
import 'package:cashu_dart/utils/tools.dart';

import '../core/nuts/nut_00.dart';

class MeltResponse {

  MeltResponse({
    required this.paid,
    required this.preimage,
    required this.change,
  });

  final bool paid;
  final String preimage;
  final List<BlindedSignature> change;

  factory MeltResponse.fromServerMap(Map json) {
    final change = (json['change']?.typedOrDefault([]) ?? []) as List;
    return MeltResponse(
      paid: json['paid']?.typedOrDefault(false) ?? false,
      preimage: json['preimage']?.typedOrDefault('') ?? '',
      change: change.map((e) => BlindedSignature.fromServerMap(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'paid': paid,
      'preimage': preimage,
      'change': change.map((e) => e.toJson()).toList(),
    };
  }
}