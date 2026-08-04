import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:mparticle_flutter_sdk/src/mparticle_web_error_codes.dart';
import 'package:mparticle_flutter_sdk/src/web_helpers/js_bridge.dart';

Never throwUserNotFound() {
  throw PlatformException(
    code: MparticleWebErrorCodes.identityUnavailable,
    message: 'User not found',
  );
}

JSObject? userForMpid({
  required MParticleJsBridge bridge,
  required JSObject identity,
  required Object? mpid,
}) {
  final user = bridge.callMethodVarArgs(identity, 'getUser', [
    bridge.jsifyValue(mpid)!,
  ]);
  if (user == null || user.isUndefinedOrNull) {
    return null;
  }
  return user as JSObject;
}
