/// Web-specific platform error codes aligned with `MP_INIT_*` taxonomy.
abstract final class MparticleWebErrorCodes {
  static const snippetMissing = 'MP_WEB_SNIPPET_MISSING';
  static const notReady = 'MP_WEB_NOT_READY';
  static const interopFailed = 'MP_WEB_INTEROP_FAILED';
  static const identityUnavailable = 'MP_WEB_IDENTITY_UNAVAILABLE';
  static const invalidAliasRequest = 'MP_WEB_INVALID_ALIAS_REQUEST';
  static const consentUnavailable = 'MP_WEB_CONSENT_UNAVAILABLE';
  static const commerceUnavailable = 'MP_WEB_COMMERCE_UNAVAILABLE';
  static const roktUnavailable = 'MP_WEB_ROKT_UNAVAILABLE';
}
