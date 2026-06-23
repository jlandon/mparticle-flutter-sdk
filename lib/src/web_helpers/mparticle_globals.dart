import 'dart:developer' as developer;

import 'package:flutter/services.dart';

import 'dart:js_interop';

import 'js_runtime.dart';

/// Web-specific platform error codes aligned with `MP_INIT_*` taxonomy.
abstract final class MparticleWebErrorCodes {
  static const snippetMissing = 'MP_WEB_SNIPPET_MISSING';
  static const notReady = 'MP_WEB_NOT_READY';
  static const interopFailed = 'MP_WEB_INTEROP_FAILED';
  static const identityUnavailable = 'MP_WEB_IDENTITY_UNAVAILABLE';
  static const consentUnavailable = 'MP_WEB_CONSENT_UNAVAILABLE';
  static const commerceUnavailable = 'MP_WEB_COMMERCE_UNAVAILABLE';
  static const roktUnavailable = 'MP_WEB_ROKT_UNAVAILABLE';
}

PlatformException _webPlatformException({
  required String code,
  required String message,
  String? details,
  Object? error,
  StackTrace? stackTrace,
}) {
  developer.log(
    'mParticle web interop error',
    name: 'mparticle_flutter_sdk',
    error: error,
    stackTrace: stackTrace,
  );
  return PlatformException(code: code, message: message, details: details);
}

JSObject? _lookupMParticle() {
  final value = getGlobalProperty('mParticle');
  if (value == null || value.isUndefinedOrNull) {
    return null;
  }
  return value as JSObject;
}

/// Returns `window.mParticle` or throws [PlatformException].
JSObject requireMParticle() {
  final mParticle = _lookupMParticle();
  if (mParticle == null) {
    throw _webPlatformException(
      code: MparticleWebErrorCodes.snippetMissing,
      message: 'mParticle JS SDK not found. Ensure the mParticle snippet is in '
          'index.html and loaded before waitUntilReady().',
    );
  }
  return mParticle;
}

/// Returns `window.mParticle` after verifying initialization state.
JSObject requireMParticleReady() {
  final mParticle = requireMParticle();
  try {
    final instance = callMethodVarArgsOn(mParticle, 'getInstance', []);
    if (instance == null || instance.isUndefinedOrNull) {
      throw StateError('not ready');
    }
    final store = getProperty(instance as JSObject, '_Store');
    if (store == null || store.isUndefinedOrNull) {
      throw StateError('not ready');
    }
    final isInitialized = getProperty(store as JSObject, 'isInitialized');
    if (isInitialized != true.toJS && isInitialized != true) {
      throw StateError('not ready');
    }
  } catch (error, stackTrace) {
    throw _webPlatformException(
      code: MparticleWebErrorCodes.notReady,
      message:
          'mParticle JS SDK is not initialized. Double-check your web API key '
          'and wait for waitUntilReady() before calling SDK methods.',
      error: error,
      stackTrace: stackTrace,
    );
  }
  return mParticle;
}

JSObject requireIdentity({JSObject? mParticle}) {
  final root = mParticle ?? requireMParticle();
  final identity = _lookupNamespaceFromRoot(root, 'Identity');
  if (identity == null) {
    throw _webPlatformException(
      code: MparticleWebErrorCodes.identityUnavailable,
      message: 'mParticle.Identity is unavailable.',
    );
  }
  return identity;
}

JSObject requireCommerce({JSObject? mParticle}) {
  final root = mParticle ?? requireMParticle();
  final commerce = _lookupNamespaceFromRoot(root, 'eCommerce');
  if (commerce == null) {
    throw _webPlatformException(
      code: MparticleWebErrorCodes.commerceUnavailable,
      message: 'mParticle.eCommerce is unavailable.',
    );
  }
  return commerce;
}

JSObject requireConsent({JSObject? mParticle}) {
  final root = mParticle ?? requireMParticle();
  final consent = _lookupNamespaceFromRoot(root, 'Consent');
  if (consent == null) {
    throw _webPlatformException(
      code: MparticleWebErrorCodes.consentUnavailable,
      message: 'mParticle.Consent is unavailable.',
    );
  }
  return consent;
}

JSObject requireRokt({JSObject? mParticle}) {
  final root = mParticle ?? requireMParticle();
  final rokt = _lookupNamespaceFromRoot(root, 'Rokt');
  if (rokt == null) {
    throw _webPlatformException(
      code: MparticleWebErrorCodes.roktUnavailable,
      message: 'mParticle.Rokt is unavailable.',
    );
  }
  return rokt;
}

JSObject? _lookupNamespaceFromRoot(JSObject root, String name) {
  final value = getProperty(root, name);
  if (value == null || value.isUndefinedOrNull) {
    return null;
  }
  return value as JSObject;
}

/// Request-scoped mParticle namespace cache for a single MethodChannel call.
class MParticleWebContext {
  MParticleWebContext._({required this.mParticle});

  factory MParticleWebContext.forCall({bool requireReady = false}) {
    final mParticle =
        requireReady ? requireMParticleReady() : requireMParticle();
    return MParticleWebContext._(mParticle: mParticle);
  }

  final JSObject mParticle;
  JSObject? _identity;
  JSObject? _commerce;
  JSObject? _consent;
  JSObject? _rokt;

  JSObject get identityNamespace =>
      _identity ??= requireIdentity(mParticle: mParticle);

  JSObject get commerceNamespace =>
      _commerce ??= requireCommerce(mParticle: mParticle);

  JSObject get consentNamespace =>
      _consent ??= requireConsent(mParticle: mParticle);

  JSObject get roktNamespace => _rokt ??= requireRokt(mParticle: mParticle);
}
