
import 'nut_10.dart';

enum P2PKSecretSigFlag {
  inputs('SIG_INPUTS'),
  all('SIG_ALL');

  const P2PKSecretSigFlag(this.value);
  final String value;

  static P2PKSecretSigFlag? fromValue(dynamic value) {
    return P2PKSecretSigFlag.values.where((element) => element.value == value).firstOrNull;
  }
}

enum P2PKSecretTagKey {

  sigflag('sigflag'),
  nSigs('n_sigs'),
  lockTime('locktime'),
  refund('refund'),
  pubkeys('pubkeys');

  const P2PKSecretTagKey(this.name);
  final String name;

  List<String> appendValues(List<String> values) {
    return [name, ...values];
  }
}

class P2PKSecret with Nut10 {
  const P2PKSecret({
    required this.nonce,
    required this.data,
    this.tags = const [],
  });

  @override
  ConditionType get type => ConditionType.p2pk;

  @override
  final String nonce;

  @override
  final String data;

  @override
  final List<List<String>> tags;
}

class P2PKWitness {
  const P2PKWitness(this.signatures);
  final List<String> signatures;
}