class ProfileImageInfo {
  final String source;
  final String url;
  final String imageUrl;
  final String assetKey;

  const ProfileImageInfo({
    required this.source,
    required this.url,
    required this.imageUrl,
    required this.assetKey,
  });

  factory ProfileImageInfo.fromJson(dynamic value) {
    if (value is! Map<String, dynamic>) return ProfileImageInfo.empty;
    return ProfileImageInfo(
      source: _asString(value['source']),
      url: _asString(value['url']),
      imageUrl: _asString(value['image_url']),
      assetKey: _asString(value['asset_key']),
    );
  }

  static const empty = ProfileImageInfo(
    source: 'none',
    url: '',
    imageUrl: '',
    assetKey: '',
  );

  String get displayUrl => url.isNotEmpty ? url : imageUrl;
  bool get hasDisplayImage => displayUrl.isNotEmpty;
  bool get isLocalAsset => displayUrl.startsWith('assets/');
  bool get isDataUrl => displayUrl.startsWith('data:image/');
  bool get isNetworkImage =>
      displayUrl.startsWith('http://') || displayUrl.startsWith('https://');
}

String _asString(dynamic value) {
  if (value is String) return value.trim();
  return '';
}
