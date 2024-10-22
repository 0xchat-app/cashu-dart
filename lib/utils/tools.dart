
import 'dart:convert';
import 'dart:typed_data';
import 'package:cbor/cbor.dart';

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

  Uint8List base64AsBytes() {
    return base64.decode(this);
  }

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

  T decodeBase64ToMapByJson<T>() {
    String normalizedBase64 = base64FromBase64url();
    final decoded = base64.decode(normalizedBase64);
    final jsonString = utf8.decode(decoded);
    return json.decode(jsonString) as T;
  }

  T decodeBase64ToMapByCBOR<T>() {
    String normalizedBase64 = base64FromBase64url();
    final decoded = base64.decode(normalizedBase64);
    final cborValue = cbor.decode(decoded);
    return cborValue.toJson() as T;
  }

  String base64FromBase64url() {
    String normalizedBase64 = replaceAll('-', '+').replaceAll('_', '/');
    while (normalizedBase64.length % 4 != 0) {
      normalizedBase64 += '=';
    }
    return normalizedBase64;
  }

  String base64urlFromBase64() {
    String output = replaceAll('+', '-').replaceAll('/', '_');
    return output.split('=')[0];
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

