
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

import '../model/define.dart';

class Tools {

  static T getValueAs<T>(Map map, String key, T defaultValue) {
    var value = map[key];
    if (value is T) {
      return value;
    }
    return defaultValue;
  }
}

extension ToolsEx on Object {
  T typedOrDefault<T>(T defaultValue) {
    if (this is T) {
      return this as T;
    }
    return defaultValue;
  }
}

extension Uint8ListEx on Uint8List {
  String asHex() {
    return map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  String asUTF8String() {
    return utf8.decode(this);
  }

  String asBase64String() {
    return base64.encode(this);
  }

  BigInt asBigInt() {
    final hexString = map(
      (byte) => byte.toRadixString(16).padLeft(2, '0'),
    ).join();
    return BigInt.parse(hexString, radix: 16);
  }
}

extension StringHexEx on String {

  BigInt asBigInt() => BigInt.tryParse(this) ?? BigInt.zero;

  Uint8List asBytes() {
    return Uint8List.fromList(utf8.encode(this));
  }

  Uint8List hexToBytes() {
    List<int> bytes = [];
    for (int i = 0; i < length; i += 2) {
      bytes.add(int.parse(substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  T encodeBase64ToJson<T>() {
    final normalizedBase64 = replaceAll('-', '+').replaceAll('_', '/');
    final decoded = base64.decode(normalizedBase64);
    final jsonString = utf8.decode(decoded);
    return json.decode(jsonString) as T;
  }
}

extension BigIntEx on BigInt {
  Uint8List encodeBigInt() {
    int size = (bitLength + 7) ~/ 8;
    Uint8List result = Uint8List(size);
    for (int i = 0; i < size; i++) {
      result[size - i - 1] =
      ((this >> (8 * i)) & BigInt.from(0xff)).toInt() & 0xff;
    }
    return result;
  }
}

extension MintKeysEx on MintKeys {
  String deriveKeysetId() {
    final keys = entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final pubkeysConcat = keys.map((entry) => entry.value).join('');

    var bytes = utf8.encode(pubkeysConcat);
    var hash = sha256.convert(bytes);

    return base64.encode(hash.bytes).substring(0, 12);
  }
}
