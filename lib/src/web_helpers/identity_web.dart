import 'dart:async';

import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:mparticle_flutter_sdk/src/web_helpers/js_bridge.dart';
import 'package:mparticle_flutter_sdk/src/web_helpers/web_identity_helpers.dart';

/// Identity JS interop for web — see also [web_identity_helpers.dart] (pure Dart).
///
/// Cross-reference: [package:mparticle_flutter_sdk/src/identity/identity_helpers.dart]
/// parses identity wire JSON on the Dart API layer.

const _identityCallbackTimeout = Duration(seconds: 60);

/// Canonical async JS callback pattern for identity methods.
Future<String> invokeIdentityCallback({
  required MParticleJsBridge bridge,
  required JSObject identity,
  required String identityMethod,
  required Map<String, dynamic> identityRequest,
  Duration timeout = _identityCallbackTimeout,
}) {
  final completer = Completer<String>();
  JSFunction? callbackRef;
  Timer? timer;

  void completeWithResult(JSAny resultAny) {
    if (completer.isCompleted) {
      return;
    }

    try {
      if (resultAny.isUndefinedOrNull) {
        completer.complete(
          buildIdentityResultJson(
            httpCode: -1,
            mpid: null,
            previousMpid: null,
            body: 'Identity callback returned no result',
            errors: null,
            identityMethod: identityMethod,
          ),
        );
        return;
      }

      final result = resultAny as JSObject;
      final httpCode = _readHttpCode(bridge, result);
      final mpid = _readMpid(bridge, result);
      final previousMpid = identityMethod == 'modify'
          ? null
          : _readPreviousMpid(bridge, result);

      List<Map<String, String?>>? errors;
      Object? body;

      switch (httpCode) {
        case 400:
        case 401:
        case 429:
          errors = convertJSErrorArraytoDartErrorList(bridge, result);
          break;
        case -1:
        case -2:
        case -3:
        case -4:
        case -5:
          body = _readBody(bridge, result);
          break;
        default:
          if (httpCode != null && httpCode >= 500) {
            final bodyValue = bridge.getProperty(result, 'body');
            final bodyMap = bridge.jsDartify(bodyValue);
            if (bodyMap is Map) {
              body = bodyMap;
            }
          }
      }

      completer.complete(
        buildIdentityResultJson(
          httpCode: httpCode,
          mpid: mpid,
          previousMpid: previousMpid,
          body: body,
          errors: errors,
          identityMethod: identityMethod,
          onUnknownHttpCode: (_) {},
        ),
      );
    } catch (_) {
      completer.complete(
        buildIdentityResultJson(
          httpCode: -1,
          mpid: null,
          previousMpid: null,
          body: 'Identity callback result could not be parsed',
          errors: null,
          identityMethod: identityMethod,
        ),
      );
    } finally {
      timer?.cancel();
    }
  }

  void onTimeout() {
    if (completer.isCompleted) {
      return;
    }
    completer.complete(buildIdentityTimeoutJson());
  }

  callbackRef = ((JSAny result) {
    completeWithResult(result);
  }).toJS;

  timer = Timer(timeout, onTimeout);

  bridge.callMethodVarArgs(identity, identityMethod, [
    bridge.jsifyValue(identityRequest),
    callbackRef,
  ]);

  return completer.future.whenComplete(() {
    timer?.cancel();
    callbackRef = null;
  });
}

Future<String> sendIdentityCall({
  required MParticleJsBridge bridge,
  required JSObject identity,
  required String identityMethod,
  required Map<dynamic, dynamic> identityRequestMap,
}) {
  final identityRequest = createWebIdentityRequest(identityRequestMap);
  return invokeIdentityCallback(
    bridge: bridge,
    identity: identity,
    identityMethod: identityMethod,
    identityRequest: identityRequest,
  );
}

List<Map<String, String?>> convertJSErrorArraytoDartErrorList(
  MParticleJsBridge bridge,
  JSObject result,
) {
  final body = bridge.getProperty(result, 'body');
  if (body == null || body.isUndefinedOrNull) {
    return [];
  }
  final errors = bridge.getProperty(body as JSObject, 'errors');
  if (errors == null || errors.isUndefinedOrNull) {
    return [];
  }

  final dartified = bridge.jsDartify(errors);
  if (dartified is List) {
    return convertDartErrorList(dartified);
  }

  final decoded = bridge.stringifyAndDecode(errors);
  if (decoded is List) {
    return convertDartErrorList(decoded);
  }
  return [];
}

Map<String, dynamic> createAliasRequest({
  required MParticleJsBridge bridge,
  required Map<dynamic, dynamic> aliasRequest,
  required JSObject mParticle,
  required JSObject identity,
}) {
  final sourceMpid = aliasRequest['sourceMpid'] as String;
  final destinationMpid = aliasRequest['destinationMpid'] as String;

  final instance = bridge.callMethodVarArgs(mParticle, 'getInstance', []);
  final store = bridge.getProperty(instance! as JSObject, '_Store') as JSObject;
  final sdkConfig = bridge.getProperty(store, 'SDKConfig') as JSObject;
  final aliasMaxWindowValue = bridge.getProperty(sdkConfig, 'aliasMaxWindow');
  final aliasMaxWindowDays = _toInt(aliasMaxWindowValue) ?? 0;

  final user =
      bridge.callMethodVarArgs(identity, 'getUser', [
            bridge.jsifyValue(sourceMpid)!,
          ])
          as JSObject;

  final startTime =
      _toInt(bridge.callMethodVarArgs(user, 'getFirstSeenTime', [])) ?? 0;
  final endTimeRaw = bridge.callMethodVarArgs(user, 'getLastSeenTime', []);
  final endTime = endTimeRaw == null || endTimeRaw.isUndefinedOrNull
      ? null
      : _toInt(endTimeRaw);

  final window = computeAliasWindow(
    nowMs: DateTime.now().millisecondsSinceEpoch,
    aliasMaxWindowDays: aliasMaxWindowDays,
    startTime: startTime,
    endTime: endTime,
  );

  var resolvedEndTime = window.endTime;
  if (window.warnOutsideWindow && resolvedEndTime < window.startTime) {
    resolvedEndTime = window.startTime;
  }

  return {
    'destinationMpid': destinationMpid,
    'sourceMpid': sourceMpid,
    'startTime': window.startTime,
    'endTime': resolvedEndTime,
  };
}

Future<void> aliasUsers({
  required MParticleJsBridge bridge,
  required JSObject identity,
  required JSObject mParticle,
  required Map<dynamic, dynamic> jsAliasRequest,
}) async {
  if (jsAliasRequest['startTime'] != null &&
      jsAliasRequest['endTime'] != null) {
    bridge.callMethodVarArgs(identity, 'aliasUsers', [
      bridge.jsifyValue(jsAliasRequest)!,
    ]);
    return;
  }

  if (jsAliasRequest['startTime'] == null &&
      jsAliasRequest['endTime'] == null) {
    final createdAliasRequest = createAliasRequest(
      bridge: bridge,
      aliasRequest: jsAliasRequest,
      mParticle: mParticle,
      identity: identity,
    );
    bridge.callMethodVarArgs(identity, 'aliasUsers', [
      bridge.jsifyValue(createdAliasRequest)!,
    ]);
    return;
  }

  throw PlatformException(
    code: MparticleWebErrorCodes.invalidAliasRequest,
    message:
        'aliasUsers requires both startTime and endTime, or neither (partial alias window is invalid)',
  );
}

int? _readHttpCode(MParticleJsBridge bridge, JSObject result) {
  final value = bridge.getProperty(result, 'httpCode');
  if (value == null || value.isUndefinedOrNull) {
    return null;
  }
  return _toInt(value);
}

String? _readMpid(MParticleJsBridge bridge, JSObject result) {
  final user = bridge.callMethodVarArgs(result, 'getUser', []);
  if (user == null || user.isUndefinedOrNull) {
    return null;
  }
  final mpid = bridge.callMethodVarArgs(user as JSObject, 'getMPID', []);
  return mpid?.dartify()?.toString();
}

String? _readPreviousMpid(MParticleJsBridge bridge, JSObject result) {
  final user = bridge.callMethodVarArgs(result, 'getPreviousUser', []);
  if (user == null || user.isUndefinedOrNull) {
    return null;
  }
  final mpid = bridge.callMethodVarArgs(user as JSObject, 'getMPID', []);
  return mpid?.dartify()?.toString();
}

Object? _readBody(MParticleJsBridge bridge, JSObject result) {
  final body = bridge.getProperty(result, 'body');
  if (body == null || body.isUndefinedOrNull) {
    return null;
  }
  return body.dartify();
}

int? _toInt(JSAny? value) {
  final dart = value?.dartify();
  if (dart is int) {
    return dart;
  }
  if (dart is double) {
    return dart.toInt();
  }
  if (dart is String) {
    return int.tryParse(dart);
  }
  return null;
}
