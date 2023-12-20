
import '../model/define.dart';
import '../utils/network/http_client.dart';
import '../model/blinded_message.dart';
import '../model/melt_response.dart';
import '../model/mint_info.dart';
import 'nuts/nut_00.dart';

class CashuMint {

  CashuMint(this.mintURL);

  final String mintURL;

  String joinUrls(String path) => '$mintURL/$path';

  /// fetches mints info at the /info endpoint
  Future<MintInfo?> getInfo(String mintUrl) {
    return HTTPClient.get(
      joinUrls('info'),
      modelBuilder: (json) {
        if (json is! Map) return null;
        return MintInfo.fromServerMap(json);
      },
    );
  }

  /// Starts a minting process by requesting an invoice from the mint
  /// [amount] Amount requesting for mint.
  /// Returns the mint will create and return a Lightning invoice for the specified amount
  Future<MintResponse?> requestMint(num amount) async {
    return HTTPClient.get(
      joinUrls('mint'),
      query: {'amount': amount.toString()},
      modelBuilder: (json) {
        if (json is! Map) return null;
        final pr = json['pr']?.typedOrDefault('') ?? '';
        final hashValue = json['hash']?.typedOrDefault('') ?? '';
        return (pr: pr, hashValue: hashValue);
      },
    );
  }

  /// Requests the mint to perform token minting after the LN invoice has been paid
  /// [payloads] outputs (Blinded messages) that can be written
  /// [hash] hash (id) used for by the mint to keep track of wether the invoice has been paid yet
  /// Returns serialized blinded signatures
  Future<List<BlindedSignature>?> mint(List<SerializedBlindedMessage> payloads, String hash) async {
    return HTTPClient.post(
      joinUrls('mint'),
      query: {'hash': hash},
      params: {'outputs': payloads.map((e) => e.toJson())},
      modelBuilder: (json) {
        if (json is! List) return null;
        return (json as List).map((e) {
          if (e is! Map) return null;
          return BlindedSignature.fromServerMap(e);
        }).where((element) => element != null).toList().cast();
      },
    );
  }

  /// Get the mints public keys
  /// [keysetId] optional param to get the keys for a specific keyset. If not specified, the keys from the active keyset are fetched
  /// Returns the mints public keys
  Future<MintKeys?> getKeys({String? keysetId}) async {
    var endpoint = 'keys';
    if (keysetId != null) {
      keysetId = Uri.encodeComponent(keysetId);
      endpoint = joinUrls('keys/$keysetId');
    } else {
      endpoint = joinUrls(endpoint);
    }
    return HTTPClient.get(
      endpoint,
      modelBuilder: (json) {
        if (json is Map) {
          return json.map((key, value) {
            return MapEntry(key.toString(), value.toString());
          }).cast<String, String>();
        } else {
          return null;
        }
      },
    );
  }

  /// Get the mints keysets in no specific order
  /// Returns all the mints past and current keysets.
  Future<List<String>?> getKeySets() async {
    return HTTPClient.get(
      joinUrls('keysets'),
      modelBuilder: (json) => json,
    );
  }

  /// Ask mint to perform a split operation
  /// [splitPayload] data needed for performing a token split
  /// Returns split tokens
  Future<List<BlindedSignature>?> split(SplitPayload splitPayload) async {
    return HTTPClient.post<List<BlindedSignature>>(
      joinUrls('split'),
      params: {
        'proofs': splitPayload.proofs.map((e) => e.toMap()).toList(),
        'outputs': splitPayload.outputs.map((e) => e.toJson()).toList(),
      },
      modelBuilder: (json) {
        final promises = json['promises'];
        if (promises is! List<Map>) return null;
        return promises.map((json) => BlindedSignature.fromServerMap(json)).toList();
      },
    );
  }

  /// Ask mint to perform a melt operation.
  /// This pays a lightning invoice and destroys tokens matching its amount + fees
  Future<MeltResponse?> melt({
    String pr = '',
    List<Proof> proofs = const [],
    List<SerializedBlindedMessage> outputs = const [],
  }) async {
    return HTTPClient.post(
      joinUrls('melt'),
      params: {
        'pr': pr,
        'proofs': proofs.map((e) => e.toMap()).toList(),
        'outputs': outputs.map((e) => e.toJson()).toList(),
      },
      modelBuilder: (json) => MeltResponse.fromServerMap(json),
    );
  }

  /// Estimate fees for a given LN invoice
  /// Returns estimated Fee
  Future<num?> checkFees(String pr) async {
    return HTTPClient.post<num>(
      joinUrls('checkfees'),
      params: {'pr': pr},
      modelBuilder: (json) => json['fee']?.typedOrDefault(null),
    );
  }

  /// Checks if specific proofs have already been redeemed
  /// checkPayload
  /// Returns redeemed and unredeemed ordered list of booleans
  Future<List<bool>?> check(List<String> proofsSecret) async {
    return HTTPClient.post<List<bool>>(
      joinUrls('check'),
      params: {'proofs': proofsSecret},
      modelBuilder: (json) {
        final spendable = (json['spendable']?.typedOrDefault([]) ?? []) as List;
        if (spendable is List<bool>) return spendable;
        return null;
      },
    );
  }
}