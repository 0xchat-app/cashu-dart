
class MintInfo {

  MintInfo({
    required this.version,
    required this.wallet,
    required this.debug,
    required this.cashuDir,
    required this.mintURLs,
    required this.settings,
    required this.tor,
    required this.nostrPublicKey,
    required this.nostrRelays,
    required this.socksProxy,
  });

  final String version;
  final String wallet;
  final bool debug;
  final String cashuDir;
  final List<String> mintURLs;
  final String settings;
  final bool tor;
  final String nostrPublicKey;
  final List<String> nostrRelays;
  final String socksProxy;

  factory MintInfo.fromServerMap(Map json) =>
      MintInfo(
        version: json['version']?.typedOrDefault('') ?? '',
        wallet: json['wallet']?.typedOrDefault('') ?? '',
        debug: json['debug']?.typedOrDefault(false) ?? false,
        cashuDir: json['cashu_dir']?.typedOrDefault('') ?? '',
        mintURLs: json['mint_urls']?.typedOrDefault([]) ?? [],
        settings: json['settings']?.typedOrDefault('') ?? '',
        tor: json['tor']?.typedOrDefault(false) ?? false,
        nostrPublicKey: json['nostr_public_key']?.typedOrDefault('') ?? '',
        nostrRelays: json['nostr_relays']?.typedOrDefault([]) ?? [],
        socksProxy: json['socks_proxy']?.typedOrDefault('') ?? '',
      );

  @override
  String toString() {
    return '${super.toString()}, version: $version, wallet: $wallet, debug: $debug, '
        'mint_urls: $mintURLs, settings: $settings';
  }
}