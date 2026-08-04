import 'dart:convert';

import 'dart:js_interop';

import 'package:mparticle_flutter_sdk/src/web_helpers/js_bridge.dart';
import 'package:mparticle_flutter_sdk/src/web_helpers/user_lookup.dart';
import 'package:mparticle_flutter_sdk/src/web_helpers/web_identity_helpers.dart';

String getMpid({
  required MParticleJsBridge bridge,
  required JSObject identity,
}) {
  final currentUser = bridge.callMethodVarArgs(identity, 'getCurrentUser', []);
  if (currentUser == null || currentUser.isUndefinedOrNull) {
    return '';
  }
  final mpid = bridge.callMethodVarArgs(currentUser as JSObject, 'getMPID', []);
  return mpid?.dartify()?.toString() ?? '';
}

String getUserAttributes({
  required MParticleJsBridge bridge,
  required JSObject identity,
  required String mpid,
}) {
  final user = userForMpid(bridge: bridge, identity: identity, mpid: mpid);
  if (user == null) {
    return '{}';
  }

  final jsAttributes = bridge.callMethodVarArgs(
    user,
    'getAllUserAttributes',
    [],
  );

  return bridge.jsStringify(jsAttributes);
}

String getUserIdentities({
  required MParticleJsBridge bridge,
  required JSObject identity,
  required String mpid,
}) {
  final user = userForMpid(bridge: bridge, identity: identity, mpid: mpid);
  if (user == null) {
    return '{}';
  }

  final jsIdentities =
      bridge.callMethodVarArgs(user, 'getUserIdentities', []) as JSObject;

  final userIdentitiesValue = bridge.getProperty(
    jsIdentities,
    'userIdentities',
  );
  final dartified = bridge.jsDartify(userIdentitiesValue);
  if (dartified is Map) {
    return jsonEncode(identitiesNameMapToStringKeyMap(dartified));
  }

  final decoded = bridge.stringifyAndDecode(userIdentitiesValue);
  if (decoded is Map) {
    return jsonEncode(identitiesNameMapToStringKeyMap(decoded));
  }

  return '{}';
}

void setUserAttribute({
  required MParticleJsBridge bridge,
  required JSObject identity,
  required Map<dynamic, dynamic> arguments,
}) {
  final user = userForMpid(
    bridge: bridge,
    identity: identity,
    mpid: arguments['mpid'],
  );
  if (user == null) {
    throwUserNotFound();
  }

  bridge.callMethodVarArgs(user, 'setUserAttribute', [
    bridge.jsifyValue(arguments['attributeKey']),
    bridge.jsifyValue(arguments['attributeValue']),
  ]);
}

void removeUserAttribute({
  required MParticleJsBridge bridge,
  required JSObject identity,
  required Map<dynamic, dynamic> arguments,
}) {
  final user = userForMpid(
    bridge: bridge,
    identity: identity,
    mpid: arguments['mpid'],
  );
  if (user == null) {
    throwUserNotFound();
  }

  bridge.callMethodVarArgs(user, 'removeUserAttribute', [
    bridge.jsifyValue(arguments['attributeKey']),
  ]);
}

void setUserAttributeArray({
  required MParticleJsBridge bridge,
  required JSObject identity,
  required Map<dynamic, dynamic> arguments,
}) {
  final user = userForMpid(
    bridge: bridge,
    identity: identity,
    mpid: arguments['mpid'],
  );
  if (user == null) {
    throwUserNotFound();
  }

  bridge.callMethodVarArgs(user, 'setUserAttributeList', [
    bridge.jsifyValue(arguments['attributeKey']),
    bridge.jsifyValue(arguments['attributeValue']),
  ]);
}

void setUserTag({
  required MParticleJsBridge bridge,
  required JSObject identity,
  required Map<dynamic, dynamic> arguments,
}) {
  final user = userForMpid(
    bridge: bridge,
    identity: identity,
    mpid: arguments['mpid'],
  );
  if (user == null) {
    throwUserNotFound();
  }

  bridge.callMethodVarArgs(user, 'setUserTag', [
    bridge.jsifyValue(arguments['attributeKey']),
  ]);
}
