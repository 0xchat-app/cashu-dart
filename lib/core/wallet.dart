
import 'dart:math';
import 'dart:typed_data';

import 'package:cashu_dart/core/nuts/DHKE.dart';
import 'package:cashu_dart/utils/cashu_token_helper.dart';

import 'mint.dart';
import '../utils/tools.dart';
import '../model/blinded_message.dart';
import '../model/define.dart';
import 'nuts/DHKE.dart';
import 'nuts/nut_00.dart';

class CashuWallet {
  MintKeys _keys;
  String _keysetId = '';
  final CashuMint mint;

  CashuWallet(this.mint, [MintKeys? keys])
      : _keys = keys ?? {} {
    if (keys != null) {
      _keysetId = _keys.deriveKeysetId();
    }
  }

  MintKeys get keys => _keys;
  set keys(MintKeys keys) {
    _keys = keys;
    _keysetId = _keys.deriveKeysetId();
  }

  String get keysetId => _keysetId;

  Future<List<String>> checkProofsSpent(List<String> proofsSecretList) async {
    final spendable = await mint.check(proofsSecretList);
    if (spendable == null) return [];
    return List<String?>.generate(proofsSecretList.length, (i) => spendable[i] ? null : proofsSecretList[i]).whereType<String>().toList();
  }

  Future<MintResponse?> requestMint(double amount) async {
    return await mint.requestMint(amount);
  }

  Future<PayLnInvoiceResponse?> payLnInvoice(
    String invoice,
    List<Proof> proofsToSend,
    [double? feeReserve]
  ) async {
    feeReserve ??= await getFee(invoice);
    if (feeReserve == null) return null;

    final outputData = createBlankOutputs(feeReserve);
    if (outputData == null) return null;

    final payData = await mint.melt(
      pr: invoice,
      proofs: proofsToSend,
      outputs: outputData.blindedMessages,
    );
    if (payData == null) return null;

    final keys = await getKeys(arr: payData.change);
    if (keys == null) return null;

    List<Proof> change = [];
    if (payData.change.isNotEmpty) {
      change = DHKE.constructProofs(
        promises: payData.change,
        rs: outputData.rs,
        secrets: outputData.secrets,
        keys: keys,
      ) ?? [];
    }
    var newKeys = await changedKeys(payData.change) ?? {};

    return (
      isPaid: payData.paid,
      preimage: payData.preimage,
      change: change,
      newKeys: newKeys,
    );
  }

  Future<double?> getFee(String invoice) async {
    return (await mint.checkFees(invoice))?.toDouble();
  }

  PaymentPayload createPaymentPayload(String invoice, List<Proof> proofs) {
    return (
      pr: invoice,
      proofs: proofs,
    );
  }

  Future<PayLnInvoiceResponse?> payLnInvoiceWithToken(String invoice, String token) async {
    final decodedToken = CashuTokenHelper.getDecodedToken(token);
    if (decodedToken == null) return null;

    final proofs = decodedToken.token
        .where((t) => t.mint == mint.mintURL)
        .expand((t) => t.proofs)
        .toList();
    return payLnInvoice(invoice, proofs);
  }

  Future<void> initKeys() async {
    if (_keysetId.isEmpty || _keys.keys.isEmpty) {
      _keys = await mint.getKeys() ?? {};
      _keysetId = _keys.deriveKeysetId();
    }
  }

  Future<MintKeys?> changedKeys(List<BlindedSignature> promises) async {
    await initKeys();
    if (promises.isEmpty) {
      return null;
    }
    if (!promises.any((x) => x.id != _keysetId)) {
      return null;
    }
    final maybeNewKeys = await mint.getKeys();
    final keysetId = maybeNewKeys?.deriveKeysetId();
    return keysetId == _keysetId ? null : maybeNewKeys;
  }

  Future<MintKeys?> getKeys({
    required List<BlindedSignature> arr,
    String? mintUrl,
  }) async {
    await initKeys();
    if (arr.isEmpty || arr.first.id.isEmpty) {
      return _keys;
    }

    var keysetId = arr[0].id;
    if (_keysetId == keysetId) {
      return _keys;
    }

    if (mintUrl == null || mintUrl == mint.mintURL) {
      return mint.getKeys(keysetId: arr.first.id);
    } else {
      return CashuMint(mintUrl).getKeys(keysetId: arr.first.id);
    }
  }

  SplitPayloadResult createSplitPayload({
    required BigInt amount,
    required List<Proof> proofsToSend,
    List<AmountPreference>? preference,
  }) {
    BigInt totalAmount = proofsToSend.fold(BigInt.zero, (total, curr) => total + curr.amount.asBigInt());
    final keepBlindedMessages = createRandomBlindedMessages(
      amount: totalAmount - amount,
    );
    final sendBlindedMessages = createRandomBlindedMessages(
      amount: amount,
      amountPreference: preference,
    );
    BlindedTransaction blindedMessages = (
      blindedMessages: [...keepBlindedMessages.blindedMessages, ...sendBlindedMessages.blindedMessages],
      secrets: [...keepBlindedMessages.secrets, ...sendBlindedMessages.secrets],
      rs: [...keepBlindedMessages.rs, ...sendBlindedMessages.rs],
      amounts: [...keepBlindedMessages.amounts ?? [], ...sendBlindedMessages.amounts ?? []],
    );

    SplitPayload payload = (proofs: proofsToSend, outputs: blindedMessages.blindedMessages);

    return (payload: payload, blindedMessages: blindedMessages);
  }

  BlindedMessageData createRandomBlindedMessages({
    required BigInt amount,
    List<AmountPreference>? amountPreference,
  }) {
    List<SerializedBlindedMessage> blindedMessages = [];
    List<Uint8List> secrets = [];
    List<BigInt> rs = [];
    List<int> amounts = CashuTokenHelper.splitAmount(amount.toInt(), amountPreference);

    for (final amount in amounts) {
      final secret = DHKE.randomPrivateKey();
      final (B_, r) = DHKE.blindMessage(secret);
      if (B_.isEmpty) continue;

      final blindedMessage = SerializedBlindedMessage(
        amount: amount,
        B_: B_,
      );
      blindedMessages.add(blindedMessage);
      secrets.add(secret);
      rs.add(r);
    }

    return (blindedMessages: blindedMessages, secrets: secrets, rs: rs, amounts: amounts);
  }

  BlindedMessageData? createBlankOutputs(num feeReserve) {
    // final List<SerializedBlindedMessage> blindedMessages = [];
    // final List<Uint8List> secrets = [];
    // List<BigInt> rs = [];
    // int count = max(1, (log(feeReserve) / ln2).ceil());
    //
    // for (int i = 0; i < count; i++) {
    //   Uint8List secret = Tools.randomBytes(32);
    //   final result = DHKE.blindMessage(secret);
    //   if (result == null) return null;
    //
    //   rs.add(result.r);
    //   final blindedMessage = SerializedBlindedMessage(
    //     amount: 0,
    //     B_: DHKE.ecPointToHex(result.B_),
    //   );
    //   blindedMessages.add(blindedMessage);
    // }
    //
    // return (blindedMessages: blindedMessages, secrets: secrets, rs: rs, amounts: null);
  }
}

extension CashuWalletReceiveEx on CashuWallet {

  Future<ReceiveResponse?> receive({
    required String encodedToken,
    List<AmountPreference>? preference,
  }) async {
    final decodedToken = CashuTokenHelper.getDecodedToken(encodedToken);
    if (decodedToken == null) return null;

    final cleanedToken = CashuTokenHelper.cleanToken(decodedToken);
    List<TokenEntry> tokenEntries = [];
    List<TokenEntry> tokenEntriesWithError = [];
    MintKeys? newKeys;

    for (final tokenEntry in cleanedToken.token) {
      if (tokenEntry.proofs.isEmpty) continue;
      try {
        final receiveResult = await receiveTokenEntry(tokenEntry: tokenEntry, preference: preference);
        print('[Cashu - receive] receiveResult: $receiveResult');
        final proofsWithError = receiveResult.proofsWithError;
        final proofs = receiveResult.proofs;
        final newKeysFromReceive = receiveResult.newKeys;

        if (proofsWithError.isNotEmpty) {
          tokenEntriesWithError.add(tokenEntry);
          continue;
        }

        tokenEntries.add(TokenEntry(mint: tokenEntry.mint, proofs: proofs));
        newKeys ??= newKeysFromReceive;
      } catch (error) {
        print('[Cashu - receive] error: $error');
        tokenEntriesWithError.add(tokenEntry);
      }
    }

    return (
      token: Token(token: tokenEntries),
      tokensWithErrors: tokenEntriesWithError.isNotEmpty ? Token(token: tokenEntriesWithError) : null,
      newKeys: newKeys,
    );
  }

  Future<ReceiveTokenEntryResponse> receiveTokenEntry({
    required TokenEntry tokenEntry,
    List<AmountPreference>? preference,
  }) async {
    List<Proof> proofsWithError = [];
    List<Proof> proofs = [];
    MintKeys? newKeys;

    try {
      print('[Cashu - receiveTokenEntry] 00');
      int amount = tokenEntry.proofs.fold(0, (total, curr) => total + int.parse(curr.amount));
      preference ??= CashuTokenHelper.getDefaultAmountPreference(amount);

      print('[Cashu - receiveTokenEntry] 11');
      final splitResult = createSplitPayload(
        amount: BigInt.parse(amount.toString()),
        proofsToSend: tokenEntry.proofs,
        preference: preference,
      );

      print('[Cashu - receiveTokenEntry] 22');
      final promises = await CashuMint(tokenEntry.mint).split(splitResult.payload);
      if (promises == null) throw Exception('split failed');

      print('[Cashu - receiveTokenEntry] 33');
      final keys = await getKeys(arr: promises, mintUrl: tokenEntry.mint);
      if (keys == null) throw Exception('getKeys failed');

      print('[Cashu - receiveTokenEntry] 44');
      final newProofs = DHKE.constructProofs(
        promises: promises,
        rs: splitResult.blindedMessages.rs,
        secrets: splitResult.blindedMessages.secrets,
        keys: keys,
      );
      print('[Cashu - receiveTokenEntry] promises: $promises');
      print('[Cashu - receiveTokenEntry] rs: ${splitResult.blindedMessages.rs}');
      print('[Cashu - receiveTokenEntry] secrets: ${splitResult.blindedMessages.secrets}');
      print('[Cashu - receiveTokenEntry] keys: $keys');
      print('[Cashu - receiveTokenEntry] newProofs: $newProofs');
      if (newProofs == null) throw Exception('construct proofs failed');

      proofs.addAll(newProofs);
      newKeys = tokenEntry.mint == mint.mintURL ? await changedKeys(promises) : null;
    } catch (error, stackTrace) {
      print('[Cashu - receiveTokenEntry] error: $error, $stackTrace');
      proofsWithError.addAll(tokenEntry.proofs);
    }

    return (
      proofs: proofs,
      proofsWithError: proofsWithError,
      newKeys: newKeys,
    );
  }
}

extension CashuWalletSendEx on CashuWallet {

  Future<SendResponse?> send({
    required int amount,
    required List<Proof> proofs,
    List<AmountPreference>? preference,
  }) async {
    if (preference != null) {
      amount = preference.fold(0, (acc, curr) => acc + curr.amount.toInt() * curr.count.toInt());
    }

    int amountAvailable = 0;
    List<Proof> proofsToSend = [];
    List<Proof> proofsToKeep = [];

    for (var proof in proofs) {
      if (amountAvailable >= amount) {
        proofsToKeep.add(proof);
        continue;
      }
      amountAvailable += int.parse(proof.amount);
      proofsToSend.add(proof);
    }

    if (amount > amountAvailable) {
      return null;
    }

    if (amount == amountAvailable || preference == null) {
      return (
        returnChange: proofsToKeep,
        send: proofsToSend,
        newKeys: null,
      );
    }

    final splitResult = splitReceive(amount, amountAvailable);
    final splitPayload = createSplitPayload(
      amount: BigInt.parse(splitResult.amountSend.toString()),
      proofsToSend: proofsToSend,
      preference: preference,
    );
    final promises = await mint.split(splitPayload.payload);
    if (promises == null) return null;

    final keys = await getKeys(arr: promises);
    if (keys == null) return null;

    final newProofs = DHKE.constructProofs(
      promises: promises,
      rs: splitPayload.blindedMessages.rs,
      secrets: splitPayload.blindedMessages.secrets,
      keys: keys,
    );
    if (newProofs == null) return null;

    List<Proof> splitProofsToKeep = [];
    List<Proof> splitProofsToSend = [];
    int amountKeepCounter = 0;

    for (var proof in newProofs) {
      if (amountKeepCounter < splitResult.amountKeep) {
        amountKeepCounter += int.parse(proof.amount);
        splitProofsToKeep.add(proof);
        continue;
      }
      splitProofsToSend.add(proof);
    }

    return (
      returnChange: [...splitProofsToKeep, ...proofsToKeep],
      send: splitProofsToSend,
      newKeys: await changedKeys(promises),
    );
  }

  SplitReceiveResponse splitReceive(int amount, int amountAvailable) {
    int amountKeep = amountAvailable - amount;
    int amountSend = amount;
    return (amountKeep: amountKeep, amountSend: amountSend);
  }
}