
import 'package:cashu_dart/utils/tools.dart';

class MintInfo {

  MintInfo({
    required this.version,
    required this.wallet,
    required this.debug,
    required this.cashu_dir,
    required this.mint_urls,
    required this.settings,
    required this.tor,
    required this.nostr_public_key,
    required this.nostr_relays,
    required this.socks_proxy,
  });

  final String version;
  final String wallet;
  final bool debug;
  final String cashu_dir;
  final List<String> mint_urls;
  final String settings;
  final bool tor;
  final String nostr_public_key;
  final List<String> nostr_relays;
  final String socks_proxy;

  factory MintInfo.fromServerMap(Map json) =>
      MintInfo(
        version: json['version']?.typedOrDefault('') ?? '',
        wallet: json['wallet']?.typedOrDefault('') ?? '',
        debug: json['debug']?.typedOrDefault(false) ?? false,
        cashu_dir: json['cashu_dir']?.typedOrDefault('') ?? '',
        mint_urls: json['mint_urls']?.typedOrDefault([]) ?? [],
        settings: json['settings']?.typedOrDefault('') ?? '',
        tor: json['tor']?.typedOrDefault(false) ?? false,
        nostr_public_key: json['nostr_public_key']?.typedOrDefault('') ?? '',
        nostr_relays: json['nostr_relays']?.typedOrDefault([]) ?? [],
        socks_proxy: json['socks_proxy']?.typedOrDefault('') ?? '',
      );
}