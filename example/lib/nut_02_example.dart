
import 'package:cashu_dart/core/nuts/nut_01.dart';
import 'package:cashu_dart/core/nuts/nut_02.dart';

void main() async {

  final keyset = await Nut1.requestKeys(mintURL: 'https://legend.lnbits.com/cashu/api/v1/AptDNABNBXv8gpuywhx6NV');
  print('keyset: $keyset');
  final keysetId = Nut2.deriveKeysetId(keyset!);
  print('keysetId: $keysetId');
  final specificKeyset = await Nut1.requestKeys(
    mintURL: 'https://legend.lnbits.com/cashu/api/v1/AptDNABNBXv8gpuywhx6NV',
    keysetId: keysetId,
  );
  print('specificKeyset: $specificKeyset');
  final isMatch = keyset == specificKeyset;
}
