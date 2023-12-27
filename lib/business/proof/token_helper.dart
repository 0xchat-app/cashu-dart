
import 'dart:convert';
import 'dart:math';


import '../../core/nuts/nut_00.dart';
import '../../model/define.dart';
import '../../utils/tools.dart';
import '../mint/mint_store.dart';
import '../wallet/cashu_manager.dart';

class TokenHelper {

  static const TOKEN_VERSION = 'A';
  static const TOKEN_PREFIX = 'cashu';

  static String? isCashuToken(String? token) {
    if (token == null || token.isEmpty) return null;

    var t = token;

    t = t.trim();
    int idx = t.indexOf('cashuA');
    if (idx != -1) t = t.substring(idx);

    List<String> uriPrefixes = [
      'https://wallet.nutstash.app/#',
      'https://wallet.cashu.me/?token=',
      'web+cashu://',
      'cashu://',
      'cashu:'
    ];

    for (var prefix in uriPrefixes) {
      if (t.startsWith(prefix)) {
        t = t.substring(prefix.length).trim();
        break;
      }
    }

    if (t.isEmpty) return null;

    try {
      getDecodedToken(t.trim());
    } catch (_) {
      return null;
    }

    return t.trim();
  }

  static Future<bool> isTokenSpendable(String token) async {
    try {
      final decoded = getDecodedToken(token);
      if (decoded == null || decoded.token.isEmpty) return false;

      List<Proof> usableTokenProofs = [];
      for (final t in decoded.token) {
        if (t.proofs.isEmpty) continue;

        var wallet = await CashuManager.shared.getMint(t.mint);
        var usedSecrets = null;//await wallet.checkProofsSpent(t.proofs.map((p) => p.secret).toList());

        if (usedSecrets.length == t.proofs.length) {
          continue;
        }

        usableTokenProofs.addAll(t.proofs.where((x) => !usedSecrets.contains(x.secret)).toList());
      }

      return usableTokenProofs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static TokenInfo? getTokenInfo(String encodedToken) {
    try {
      final decoded = getDecodedToken(encodedToken);
      if (decoded == null) return null;
      final mints = decoded.token.map((x) => x.mint).toList();
      return (
        mints: mints,
        value: decoded.sumProofsValue.toString(),
        decoded: decoded
      );
    } catch (e) {
      print(e);
      return null;
    }
  }

  static String getEncodedToken(Token token) {
    String json = jsonEncode(token.toJson());
    String base64Encoded = base64.encode(utf8.encode(json));
    return TOKEN_PREFIX + TOKEN_VERSION + base64Encoded;
  }

  static Token? getDecodedToken(String token) {
    List<String> uriPrefixes = ['web+cashu://', 'cashu://', 'cashu:', 'cashuA'];

    for (var prefix in uriPrefixes) {
      if (token.startsWith(prefix)) {
        token = token.substring(prefix.length);
        break;
      }
    }

    return handleTokens(token);
  }

  static Future<void> addToken(dynamic token) async {
    Token? decoded;
    if (token is String) {
      decoded = getDecodedToken(token);
    } else if (token is Token) {
      decoded = token;
    }

    if (decoded == null || decoded.token.isEmpty) return ;

    for (final token in decoded.token) {
      await MintStore.addMint(token.mint);
      // final validProofs = token.proofs.where((p) => p.C.isNotEmpty && p.amount > 0 && p.secret.isNotEmpty && p.id.isNotEmpty).toList();
      // await ProofStore.addProofs(validProofs);
    }
  }

  static Token? handleTokens(String token) {
    dynamic obj;
    try {
      obj = token.encodeBase64ToJson<Map>();
    } catch(e) { }

    if (obj == null) return null;

    // check if v3
    if (obj is Map && obj.containsKey('token')) {
      return Token.fromJson(obj);
    }

    // if v2 token return v3 format
    if (obj is Map && obj.containsKey('proofs')) {
      final proofs = obj['proofs'];
      final mints = obj['mints'];
      if (proofs is List && mints is List) {
        return Token(
          token: proofs.map((e) => TokenEntry.fromJson(e)).toList(),
          memo: mints.firstOrNull?['url'] ?? '',
        );
      }
    }

    // check if v1
    if (obj is List) {
      return Token(
        token: obj.map((e) => TokenEntry.fromJson(e)).toList(),
      );
    }

    return null;
  }

  static Token cleanToken(Token token) {
    Map<String, TokenEntry> tokenEntryMap = {};

    for (final tokenEntry in token.token) {
      if (tokenEntry.proofs.isEmpty || tokenEntry.mint.isEmpty) continue;

      if (tokenEntryMap.containsKey(tokenEntry.mint)) {
        tokenEntryMap[tokenEntry.mint]!.proofs.addAll(tokenEntry.proofs);
        continue;
      }

      tokenEntryMap[tokenEntry.mint] = TokenEntry(
        mint: tokenEntry.mint,
        proofs: List<Proof>.from(tokenEntry.proofs),
      );
    }

    final cleanedTokenEntries = tokenEntryMap.values.map((x) {
      final proofs = x.proofs
        ..sort((a, b) => a.id.compareTo(b.id));
      return TokenEntry(
        mint: x.mint,
        proofs: proofs,
      );
    }).toList();

    return Token(memo: token.memo, token: cleanedTokenEntries);
  }

  static List<int> splitAmount(int value, [List<AmountPreference>? amountPreference]) {
    List<int> chunks = [];

    if (amountPreference != null) {
      final preferenceChunks = getPreference(value, amountPreference);
      if (preferenceChunks != null) {
        chunks.addAll(preferenceChunks);
        value -= preferenceChunks.fold(0, (curr, acc) => curr + acc);
      }
    }

    for (int i = 0; i < 32; i++) {
      int mask = 1 << i;
      if ((value & mask) != 0) {
        chunks.add(pow(2, i).toInt());
      }
    }

    return chunks;
  }

  static List<int>? getPreference(int amount, List<AmountPreference> preferredAmounts) {
    List<int> chunks = [];
    int accumulator = 0;

    for (final pa in preferredAmounts) {
      final amount = pa.amount.toInt();
      if (!_isPowerOfTwo(amount)) {
        return null;
      }

      for (int i = 1; i <= pa.count; i++) {
        accumulator += amount;
        if (accumulator > amount) {
          return chunks;
        }
        chunks.add(amount);
      }
    }

    return chunks;
  }

  // Helper function to check if a number is a power of two
  static bool _isPowerOfTwo(int number) {
    return number != 0 && ((number & (number - 1)) == 0);
  }

  static List<AmountPreference> getDefaultAmountPreference(int amount) {
    final amounts = splitAmount(amount);
    return amounts.map((a) => (amount: a, count: 1)).toList();
  }
}