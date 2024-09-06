
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../core/mint_actions.dart';
import '../../core/nuts/define.dart';
import '../../core/nuts/nut_00.dart';
import '../../utils/tools.dart';
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

  static Future<bool?> isTokenSpendable(String ecashToken) async {
    final token = TokenHelper.getDecodedToken(ecashToken);
    if (token == null) return null;

    final tokenEntry = token.entries;
    for (final entry in tokenEntry) {
      final mint = await CashuManager.shared.getMint(entry.mint);
      if (mint == null) continue ;

      final response = await mint.tokenCheckAction(mintURL: mint.mintURL, proofs: entry.proofs);
      if (!response.isSuccess) return null;
      if (response.data.any((state) => state != TokenState.live)) {
        return false;
      }
    }

    return true;
  }

  static String getEncodedToken(Token token) {
    String json = jsonEncode(token.toJson());
    String base64Encoded = base64.encode(utf8.encode(json)).base64urlFromBase64();
    return TOKEN_PREFIX + TOKEN_VERSION + base64Encoded;
  }

  static Token? getDecodedToken(String token) {
    List<String> uriPrefixes = Nut0.uriPrefixes;

    for (var prefix in uriPrefixes) {
      if (token.startsWith(prefix)) {
        token = token.substring(prefix.length);
        break;
      }
    }

    return handleTokens(token);
  }

  static Token? handleTokens(String token) {
    dynamic obj;
    try {
      obj = token.encodeBase64ToJson<Map>();
    } catch(e) {
      debugPrint('[Cashu - handleTokens] $e');
    }

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
          entries: proofs.map((e) => TokenEntry.fromJson(e)).toList(),
          memo: mints.firstOrNull?['url'] ?? '',
        );
      }
    }

    // check if v1
    if (obj is List) {
      return Token(
        entries: obj.map((e) => TokenEntry.fromJson(e)).toList(),
      );
    }

    return null;
  }

  static Token cleanToken(Token token) {
    Map<String, TokenEntry> tokenEntryMap = {};

    for (final tokenEntry in token.entries) {
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

    return Token(memo: token.memo, entries: cleanedTokenEntries);
  }
}