class EnvironmentConfig {
  EnvironmentConfig._();

  /// =========================================================================
  /// 🌐 ACTIVE BASE API URL (Production Portal)
  /// -------------------------------------------------------------------------
  /// static const String baseUrl = 'https://test.methotx.in/api';
  /// static const String baseUrl = 'https://portal.methotx.com/api';
  /// =========================================================================
  static const String baseUrl = 'https://portal.methotx.com/api';


  /// Root domain used for profile images, attachments, and receipts
  /// (automatically derived from baseUrl by extracting scheme and authority)
  static String get domainUrl {
    final uri = Uri.tryParse(baseUrl);
    if (uri != null && uri.hasScheme && uri.hasAuthority) {
      return '${uri.scheme}://${uri.authority}';
    }
    return baseUrl.replaceAll('/api', '');
  }
}
