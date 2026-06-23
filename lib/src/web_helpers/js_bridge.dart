/// Wasm-safe mParticle JS bridge for Flutter Web.
///
/// Architecture and wire contracts: see `docs/web-architecture.md`.
///
/// Rules:
/// - Add new mParticle JS calls in domain modules or here — not in the handler.
/// - Use [callMethodVarArgsOn] when passing null arguments.
/// - Retain `.toJS` callback references until async Completers finish; see
///   [invokeIdentityCallback] in `identity_web.dart` as the canonical pattern.
library;

import 'dart:js_interop';

import 'js_runtime.dart' as runtime;
import 'mparticle_globals.dart' as globals;

export 'js_runtime.dart'
    show
        callMethodVarArgsOn,
        getGlobalProperty,
        getIndex,
        getProperty,
        globalJsObject,
        jsDartify,
        jsifyValue,
        jsStringify,
        stringifyAndDecode;
export 'mparticle_globals.dart'
    show
        MParticleWebContext,
        MparticleWebErrorCodes,
        requireCommerce,
        requireConsent,
        requireIdentity,
        requireMParticle,
        requireMParticleReady,
        requireRokt;

/// Injectable bridge for web JS interop (default: live browser globals).
abstract interface class MParticleJsBridge {
  static final MParticleJsBridge instance = _LiveMParticleJsBridge();

  JSObject requireMParticle();
  JSObject requireMParticleReady();
  JSObject requireIdentity({JSObject? mParticle});
  JSObject requireCommerce({JSObject? mParticle});
  JSObject requireConsent({JSObject? mParticle});
  JSObject requireRokt({JSObject? mParticle});

  String jsStringify(JSAny? value);
  Object? jsDartify(JSAny? value);
  JSAny? jsifyValue(Object? value);
  Object? stringifyAndDecode(JSAny? value);

  JSAny? callMethodVarArgs(JSObject object, String method, List<JSAny?> args);
  JSAny? getProperty(JSObject object, String name);
}

final class _LiveMParticleJsBridge implements MParticleJsBridge {
  @override
  JSObject requireMParticle() => globals.requireMParticle();

  @override
  JSObject requireMParticleReady() => globals.requireMParticleReady();

  @override
  JSObject requireIdentity({JSObject? mParticle}) =>
      globals.requireIdentity(mParticle: mParticle);

  @override
  JSObject requireCommerce({JSObject? mParticle}) =>
      globals.requireCommerce(mParticle: mParticle);

  @override
  JSObject requireConsent({JSObject? mParticle}) =>
      globals.requireConsent(mParticle: mParticle);

  @override
  JSObject requireRokt({JSObject? mParticle}) =>
      globals.requireRokt(mParticle: mParticle);

  @override
  String jsStringify(JSAny? value) => runtime.jsStringify(value);

  @override
  Object? jsDartify(JSAny? value) => runtime.jsDartify(value);

  @override
  JSAny? jsifyValue(Object? value) => runtime.jsifyValue(value);

  @override
  Object? stringifyAndDecode(JSAny? value) => runtime.stringifyAndDecode(value);

  @override
  JSAny? callMethodVarArgs(
    JSObject object,
    String method,
    List<JSAny?> args,
  ) =>
      runtime.callMethodVarArgsOn(object, method, args);

  @override
  JSAny? getProperty(JSObject object, String name) =>
      runtime.getProperty(object, name);
}
