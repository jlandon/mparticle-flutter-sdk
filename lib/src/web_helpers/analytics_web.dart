import 'dart:js_interop';

import 'package:mparticle_flutter_sdk/src/web_helpers/js_bridge.dart';

bool isInitialized({required MParticleJsBridge bridge}) {
  final mParticle = bridge.requireMParticle();
  final instance = bridge.callMethodVarArgs(mParticle, 'getInstance', []);
  final store = bridge.getProperty(instance! as JSObject, '_Store') as JSObject;
  final initialized = bridge.getProperty(store, 'isInitialized');
  return initialized == true.toJS || initialized == true;
}

String getAppName({required MParticleJsBridge bridge}) {
  final mParticle = bridge.requireMParticle();
  final name = bridge.callMethodVarArgs(mParticle, 'getAppName', []);
  return name?.dartify()?.toString() ?? '';
}

void logError({
  required MParticleJsBridge bridge,
  required Map<dynamic, dynamic> arguments,
}) {
  final mParticle = bridge.requireMParticle();
  bridge.callMethodVarArgs(mParticle, 'logError', [
    bridge.jsifyValue(arguments['eventName']),
    bridge.jsifyValue(arguments['customAttributes']),
  ]);
}

void logEvent({
  required MParticleJsBridge bridge,
  required Map<dynamic, dynamic> arguments,
}) {
  final mParticle = bridge.requireMParticle();
  final shouldUpload = arguments['shouldUploadEvent'];
  if (shouldUpload != null) {
    bridge.callMethodVarArgs(mParticle, 'logEvent', [
      bridge.jsifyValue(arguments['eventName']),
      bridge.jsifyValue(arguments['eventType']),
      bridge.jsifyValue(arguments['customAttributes']),
      bridge.jsifyValue(arguments['customFlags']),
      bridge.jsifyValue({'shouldUploadEvent': shouldUpload}),
    ]);
    return;
  }

  bridge.callMethodVarArgs(mParticle, 'logEvent', [
    bridge.jsifyValue(arguments['eventName']),
    bridge.jsifyValue(arguments['eventType']),
    bridge.jsifyValue(arguments['customAttributes']),
    bridge.jsifyValue(arguments['customFlags']),
  ]);
}

void logScreenEvent({
  required MParticleJsBridge bridge,
  required Map<dynamic, dynamic> arguments,
}) {
  final mParticle = bridge.requireMParticle();
  bridge.callMethodVarArgs(mParticle, 'logPageView', [
    bridge.jsifyValue(arguments['eventName']),
    bridge.jsifyValue(arguments['customAttributes']),
    bridge.jsifyValue(arguments['customFlags']),
  ]);
}

void setOptOut({
  required MParticleJsBridge bridge,
  required bool optOut,
}) {
  final mParticle = bridge.requireMParticle();
  bridge.callMethodVarArgs(mParticle, 'setOptOut', [
    bridge.jsifyValue(optOut),
  ]);
}

void upload({required MParticleJsBridge bridge}) {
  final mParticle = bridge.requireMParticle();
  bridge.callMethodVarArgs(mParticle, 'upload', []);
}

void roktSelectPlacements({
  required MParticleJsBridge bridge,
  required JSObject rokt,
  required Map<dynamic, dynamic> arguments,
}) {
  bridge.callMethodVarArgs(rokt, 'selectPlacements', [
    bridge.jsifyValue({
      'identifier': arguments['placementId'],
      'attributes': arguments['attributes'] ?? {},
    }),
  ]);
}
