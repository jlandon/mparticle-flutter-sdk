import 'dart:convert';

import 'dart:js_interop';

import 'package:mparticle_flutter_sdk/src/web_helpers/js_bridge.dart';
import 'package:mparticle_flutter_sdk/src/web_helpers/web_identity_helpers.dart';

JSObject? _userForMpid({
  required MParticleJsBridge bridge,
  required JSObject identity,
  required Object? mpid,
}) {
  final user = bridge.callMethodVarArgs(
    identity,
    'getUser',
    [bridge.jsifyValue(mpid)!],
  );
  if (user == null || user.isUndefinedOrNull) {
    return null;
  }
  return user as JSObject;
}

String getGdprConsentState({
  required MParticleJsBridge bridge,
  required JSObject identity,
  required String mpid,
}) {
  final user = bridge.callMethodVarArgs(
    identity,
    'getUser',
    [bridge.jsifyValue(mpid)!],
  );
  if (user == null || user.isUndefinedOrNull) {
    return '{}';
  }

  final consentState =
      bridge.callMethodVarArgs(user as JSObject, 'getConsentState', []);
  if (consentState == null || consentState.isUndefinedOrNull) {
    return '{}';
  }

  final gdprConsentState = bridge.callMethodVarArgs(
    consentState as JSObject,
    'getGDPRConsentState',
    [],
  );
  if (gdprConsentState == null || gdprConsentState.isUndefinedOrNull) {
    return '{}';
  }

  final dartified = bridge.jsDartify(gdprConsentState);
  if (dartified is Map) {
    return jsonEncode(remapGdprConsentMap(dartified));
  }
  return '{}';
}

void addGdprConsentState({
  required MParticleJsBridge bridge,
  required JSObject identity,
  required JSObject consent,
  required Map<dynamic, dynamic> arguments,
}) {
  final gdprConsent = bridge.callMethodVarArgs(
    consent,
    'createGDPRConsent',
    [
      bridge.jsifyValue(arguments['consented']),
      bridge.jsifyValue(arguments['timestamp']),
      bridge.jsifyValue(arguments['document']),
      bridge.jsifyValue(arguments['location']),
      bridge.jsifyValue(arguments['hardwareId']),
    ],
  );

  final mpid = arguments['mpid'];
  final user = _userForMpid(bridge: bridge, identity: identity, mpid: mpid);
  if (user == null) {
    return;
  }

  var consentState = bridge.callMethodVarArgs(user, 'getConsentState', []);
  if (consentState == null || consentState.isUndefinedOrNull) {
    consentState = bridge.callMethodVarArgs(consent, 'createConsentState', []);
  }

  bridge.callMethodVarArgs(
    consentState! as JSObject,
    'addGDPRConsentState',
    [
      bridge.jsifyValue(arguments['purpose']),
      gdprConsent,
    ],
  );
  bridge.callMethodVarArgs(user, 'setConsentState', [consentState]);
}

void removeGdprConsentState({
  required MParticleJsBridge bridge,
  required JSObject identity,
  required Map<dynamic, dynamic> arguments,
}) {
  final mpid = arguments['mpid'];
  final user = _userForMpid(bridge: bridge, identity: identity, mpid: mpid);
  if (user == null) {
    return;
  }

  final consentState = bridge.callMethodVarArgs(user, 'getConsentState', []);
  if (consentState == null || consentState.isUndefinedOrNull) {
    return;
  }

  bridge.callMethodVarArgs(
    consentState as JSObject,
    'removeGDPRConsentState',
    [bridge.jsifyValue(arguments['purpose'])],
  );
  bridge.callMethodVarArgs(user, 'setConsentState', [consentState]);
}

String getCcpaConsentState({
  required MParticleJsBridge bridge,
  required JSObject identity,
  required String mpid,
}) {
  final user = bridge.callMethodVarArgs(
    identity,
    'getUser',
    [bridge.jsifyValue(mpid)!],
  );
  if (user == null || user.isUndefinedOrNull) {
    return '{}';
  }

  final consentState =
      bridge.callMethodVarArgs(user as JSObject, 'getConsentState', []);
  if (consentState == null || consentState.isUndefinedOrNull) {
    return '{}';
  }

  final ccpaConsentState = bridge.callMethodVarArgs(
    consentState as JSObject,
    'getCCPAConsentState',
    [],
  );
  if (ccpaConsentState == null || ccpaConsentState.isUndefinedOrNull) {
    return '{}';
  }

  final dartified = bridge.jsDartify(ccpaConsentState);
  if (dartified is Map) {
    return jsonEncode(remapCcpaConsentMap(dartified));
  }
  return '{}';
}

void addCcpaConsentState({
  required MParticleJsBridge bridge,
  required JSObject identity,
  required JSObject consent,
  required Map<dynamic, dynamic> arguments,
}) {
  final ccpaConsent = bridge.callMethodVarArgs(
    consent,
    'createCCPAConsent',
    [
      bridge.jsifyValue(arguments['consented']),
      bridge.jsifyValue(arguments['timestamp']),
      bridge.jsifyValue(arguments['document']),
      bridge.jsifyValue(arguments['location']),
      bridge.jsifyValue(arguments['hardwareId']),
    ],
  );

  final mpid = arguments['mpid'];
  final user = _userForMpid(bridge: bridge, identity: identity, mpid: mpid);
  if (user == null) {
    return;
  }

  var consentState = bridge.callMethodVarArgs(user, 'getConsentState', []);
  if (consentState == null || consentState.isUndefinedOrNull) {
    consentState = bridge.callMethodVarArgs(consent, 'createConsentState', []);
  }

  bridge.callMethodVarArgs(
    consentState! as JSObject,
    'setCCPAConsentState',
    [ccpaConsent],
  );
  bridge.callMethodVarArgs(user, 'setConsentState', [consentState]);
}

void removeCcpaConsentState({
  required MParticleJsBridge bridge,
  required JSObject identity,
  required Map<dynamic, dynamic> arguments,
}) {
  final mpid = arguments['mpid'];
  final user = _userForMpid(bridge: bridge, identity: identity, mpid: mpid);
  if (user == null) {
    return;
  }

  final consentState = bridge.callMethodVarArgs(user, 'getConsentState', []);
  if (consentState == null || consentState.isUndefinedOrNull) {
    return;
  }

  bridge.callMethodVarArgs(
    consentState as JSObject,
    'removeCCPAConsentState',
    [],
  );
  bridge.callMethodVarArgs(user, 'setConsentState', [consentState]);
}
