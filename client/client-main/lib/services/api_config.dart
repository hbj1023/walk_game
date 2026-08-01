class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://walk-master.com',
  );

  static Uri uri(String path) {
    if (baseUrl.trim().isEmpty) {
      final normalizedPath = path.startsWith('/') ? path : '/$path';
      return Uri.base.resolve(normalizedPath);
    }
    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBaseUrl$normalizedPath');
  }
}
