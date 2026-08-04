@TestOn('browser')
import 'dart:convert';
import 'dart:js_interop';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mparticle_flutter_sdk/identity/client_error_codes.dart';
import 'package:mparticle_flutter_sdk/identity/identity_api_error_response.dart';
import 'package:mparticle_flutter_sdk/identity/identity_type.dart';
import 'package:mparticle_flutter_sdk/src/identity/identity_helpers.dart'
    as mobile_identity;
import 'package:mparticle_flutter_sdk/src/mparticle_web_error_codes.dart';
import 'package:mparticle_flutter_sdk/src/web_helpers/identity_web.dart';
import 'package:mparticle_flutter_sdk/src/web_helpers/js_bridge.dart';
import 'package:mparticle_flutter_sdk/src/web_helpers/web_identity_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'invokeIdentityCallback times out when JS callback never fires',
    () async {
      final bridge = _NonCompletingIdentityBridge();
      final completedJson = await invokeIdentityCallback(
        bridge: bridge,
        identity: JSObject(),
        identityMethod: 'identify',
        identityRequest: createWebIdentityRequest({7: 'test@example.com'}),
        timeout: const Duration(milliseconds: 50),
        timeoutGrace: const Duration(milliseconds: 25),
        lateSuccessWindow: const Duration(milliseconds: 25),
      );

      expect(completedJson, buildIdentityTimeoutJson());
      expect(bridge.identityMethodInvoked, 'identify');
    },
  );

  test(
    'invokeIdentityCallback null envelope maps to ClientNoConnection',
    () async {
      final completedJson = buildIdentityResultJson(
        httpCode: -1,
        mpid: null,
        previousMpid: null,
        body: 'Identity callback returned no result',
        errors: null,
        identityMethod: 'identify',
      );

      expect(completedJson, contains('Identity callback returned no result'));

      const channel = MethodChannel('test_null_callback');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => completedJson);

      await expectLater(
        mobile_identity.sendIdentityRequest(
          {IdentityType.Email: 'test@example.com'},
          channel,
          'identify',
        ),
        throwsA(
          isA<IdentityAPIErrorResponse>().having(
            (e) => e.clientErrorCode,
            'clientErrorCode',
            IdentityClientErrorCodes.ClientNoConnection,
          ),
        ),
      );
    },
  );

  test(
    'invokeIdentityCallback parse failure maps to ClientNoConnection',
    () async {
      final bridge = _ParseFailureCallbackBridge();
      final completedJson = await invokeIdentityCallback(
        bridge: bridge,
        identity: JSObject(),
        identityMethod: 'identify',
        identityRequest: createWebIdentityRequest({7: 'test@example.com'}),
      );

      expect(completedJson, contains('could not be parsed'));

      const channel = MethodChannel('test_parse_failure');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => completedJson);

      await expectLater(
        mobile_identity.sendIdentityRequest(
          {IdentityType.Email: 'test@example.com'},
          channel,
          'identify',
        ),
        throwsA(
          isA<IdentityAPIErrorResponse>().having(
            (e) => e.clientErrorCode,
            'clientErrorCode',
            IdentityClientErrorCodes.ClientNoConnection,
          ),
        ),
      );
    },
  );

  test(
    'invokeIdentityCallback prefers late JS success within timeout grace',
    () async {
      fakeAsync((async) {
        final bridge = _DeferredSuccessIdentityBridge();
        final future = invokeIdentityCallback(
          bridge: bridge,
          identity: JSObject(),
          identityMethod: 'identify',
          identityRequest: createWebIdentityRequest({7: 'test@example.com'}),
          timeout: const Duration(milliseconds: 50),
          timeoutGrace: const Duration(milliseconds: 100),
        );

        async.elapse(const Duration(milliseconds: 51));
        bridge.deliverSuccess(mpid: '12345');
        async.elapse(const Duration(milliseconds: 1));

        var completedJson = '';
        future.then((value) => completedJson = value);
        async.elapse(Duration.zero);

        expect(completedJson, isNot(buildIdentityTimeoutJson()));
        final decoded = jsonDecode(completedJson) as Map<String, dynamic>;
        expect(decoded['http_code'], 200);
        expect(decoded['mpid'], '12345');

        async.elapse(const Duration(milliseconds: 200));
        expect(completedJson, isNot(buildIdentityTimeoutJson()));
      });
    },
  );

  test(
    'invokeIdentityCallback prefers late JS success after timer (real async)',
    () async {
      final bridge = _DeferredSuccessIdentityBridge();
      final future = invokeIdentityCallback(
        bridge: bridge,
        identity: JSObject(),
        identityMethod: 'identify',
        identityRequest: createWebIdentityRequest({7: 'test@example.com'}),
        timeout: const Duration(milliseconds: 50),
        timeoutGrace: const Duration(milliseconds: 100),
      );

      await Future<void>.delayed(const Duration(milliseconds: 55));
      bridge.deliverSuccess(mpid: '12345');

      final completedJson = await future;
      expect(completedJson, isNot(buildIdentityTimeoutJson()));
      final decoded = jsonDecode(completedJson) as Map<String, dynamic>;
      expect(decoded['http_code'], 200);
      expect(decoded['mpid'], '12345');
    },
  );

  test(
    'invokeIdentityCallback accepts HTTP 200 after grace before timeout finalizes',
    () {
      fakeAsync((async) {
        final bridge = _DeferredSuccessIdentityBridge();
        final future = invokeIdentityCallback(
          bridge: bridge,
          identity: JSObject(),
          identityMethod: 'identify',
          identityRequest: createWebIdentityRequest({7: 'test@example.com'}),
          timeout: const Duration(milliseconds: 50),
          timeoutGrace: const Duration(milliseconds: 25),
          lateSuccessWindow: const Duration(milliseconds: 100),
        );

        async.elapse(const Duration(milliseconds: 51));
        async.elapse(const Duration(milliseconds: 30));
        bridge.deliverSuccess(mpid: '99999');
        async.elapse(Duration.zero);

        var completedJson = '';
        future.then((value) => completedJson = value);
        async.elapse(Duration.zero);

        expect(completedJson, isNot(buildIdentityTimeoutJson()));
        final decoded = jsonDecode(completedJson) as Map<String, dynamic>;
        expect(decoded['http_code'], 200);
        expect(decoded['mpid'], '99999');
      });
    },
  );

  test(
    'invokeIdentityCallback fail-closes late non-200 after grace until timeout finalizes',
    () {
      fakeAsync((async) {
        final bridge = _DeferredErrorIdentityBridge(httpCode: 400);
        final future = invokeIdentityCallback(
          bridge: bridge,
          identity: JSObject(),
          identityMethod: 'identify',
          identityRequest: createWebIdentityRequest({7: 'test@example.com'}),
          timeout: const Duration(milliseconds: 50),
          timeoutGrace: const Duration(milliseconds: 25),
          lateSuccessWindow: const Duration(milliseconds: 50),
        );

        async.elapse(const Duration(milliseconds: 51));
        async.elapse(const Duration(milliseconds: 30));
        bridge.deliver();
        async.elapse(Duration.zero);

        var completedJson = '';
        var completed = false;
        future.then((value) {
          completedJson = value;
          completed = true;
        });
        async.elapse(Duration.zero);
        expect(completed, isFalse);

        async.elapse(const Duration(milliseconds: 50));
        async.elapse(Duration.zero);
        expect(completed, isTrue);
        expect(completedJson, buildIdentityTimeoutJson());
      });
    },
  );

  test('createAliasRequest throws when source user is missing', () {
    final bridge = _MissingAliasUserBridge();
    expect(
      () => createAliasRequest(
        bridge: bridge,
        aliasRequest: {
          'sourceMpid': 'source-mpid',
          'destinationMpid': 'dest-mpid',
        },
        mParticle: JSObject(),
        identity: JSObject(),
      ),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          MparticleWebErrorCodes.identityUnavailable,
        ),
      ),
    );
  });
}

final class _NonCompletingIdentityBridge implements MParticleJsBridge {
  String? identityMethodInvoked;

  @override
  JSAny? callMethodVarArgs(JSObject object, String method, List<JSAny?> args) {
    identityMethodInvoked = method;
    return null;
  }

  @override
  JSObject requireCommerce({JSObject? mParticle}) => JSObject();

  @override
  JSObject requireConsent({JSObject? mParticle}) => JSObject();

  @override
  JSObject requireIdentity({JSObject? mParticle}) => JSObject();

  @override
  JSObject requireMParticle() => JSObject();

  @override
  JSObject requireMParticleReady() => JSObject();

  @override
  JSObject requireRokt({JSObject? mParticle}) => JSObject();

  @override
  Object? jsDartify(JSAny? value) => null;

  @override
  JSAny? jsifyValue(Object? value) => null;

  @override
  String jsStringify(JSAny? value) => '';

  @override
  Object? stringifyAndDecode(JSAny? value) => null;

  @override
  JSAny? getProperty(JSObject object, String name) => null;
}

final class _ParseFailureCallbackBridge implements MParticleJsBridge {
  @override
  JSAny? callMethodVarArgs(JSObject object, String method, List<JSAny?> args) {
    if (args.length >= 2) {
      (args[1] as JSFunction).callAsFunction(null, JSObject());
    }
    return null;
  }

  @override
  JSObject requireCommerce({JSObject? mParticle}) => JSObject();

  @override
  JSObject requireConsent({JSObject? mParticle}) => JSObject();

  @override
  JSObject requireIdentity({JSObject? mParticle}) => JSObject();

  @override
  JSObject requireMParticle() => JSObject();

  @override
  JSObject requireMParticleReady() => JSObject();

  @override
  JSObject requireRokt({JSObject? mParticle}) => JSObject();

  @override
  Object? jsDartify(JSAny? value) => null;

  @override
  JSAny? jsifyValue(Object? value) => null;

  @override
  String jsStringify(JSAny? value) => '';

  @override
  Object? stringifyAndDecode(JSAny? value) => null;

  @override
  JSAny? getProperty(JSObject object, String name) {
    throw StateError('forced parse failure');
  }
}

final class _DeferredSuccessIdentityBridge implements MParticleJsBridge {
  final JSObject successResult = JSObject();
  final JSObject userResult = JSObject();
  JSFunction? _callback;
  String? _mpid;

  void deliverSuccess({required String mpid}) {
    _mpid = mpid;
    _callback?.callAsFunction(null, successResult);
  }

  @override
  JSAny? callMethodVarArgs(JSObject object, String method, List<JSAny?> args) {
    if (method == 'identify' && args.length >= 2) {
      _callback = args[1] as JSFunction;
      return null;
    }
    if (identical(object, successResult) && method == 'getUser') {
      return userResult;
    }
    if (identical(object, userResult) && method == 'getMPID') {
      return _mpid?.toJS;
    }
    return null;
  }

  @override
  JSObject requireCommerce({JSObject? mParticle}) => JSObject();

  @override
  JSObject requireConsent({JSObject? mParticle}) => JSObject();

  @override
  JSObject requireIdentity({JSObject? mParticle}) => JSObject();

  @override
  JSObject requireMParticle() => JSObject();

  @override
  JSObject requireMParticleReady() => JSObject();

  @override
  JSObject requireRokt({JSObject? mParticle}) => JSObject();

  @override
  Object? jsDartify(JSAny? value) => null;

  @override
  JSAny? jsifyValue(Object? value) => null;

  @override
  String jsStringify(JSAny? value) => '';

  @override
  Object? stringifyAndDecode(JSAny? value) => null;

  @override
  JSAny? getProperty(JSObject object, String name) {
    if (identical(object, successResult) && name == 'httpCode') {
      return 200.toJS;
    }
    return null;
  }
}

final class _DeferredErrorIdentityBridge implements MParticleJsBridge {
  _DeferredErrorIdentityBridge({required this.httpCode});

  final int httpCode;
  final JSObject errorResult = JSObject();
  JSFunction? _callback;

  void deliver() {
    _callback?.callAsFunction(null, errorResult);
  }

  @override
  JSAny? callMethodVarArgs(JSObject object, String method, List<JSAny?> args) {
    if (method == 'identify' && args.length >= 2) {
      _callback = args[1] as JSFunction;
      return null;
    }
    return null;
  }

  @override
  JSObject requireCommerce({JSObject? mParticle}) => JSObject();

  @override
  JSObject requireConsent({JSObject? mParticle}) => JSObject();

  @override
  JSObject requireIdentity({JSObject? mParticle}) => JSObject();

  @override
  JSObject requireMParticle() => JSObject();

  @override
  JSObject requireMParticleReady() => JSObject();

  @override
  JSObject requireRokt({JSObject? mParticle}) => JSObject();

  @override
  Object? jsDartify(JSAny? value) => null;

  @override
  JSAny? jsifyValue(Object? value) => null;

  @override
  String jsStringify(JSAny? value) => '';

  @override
  Object? stringifyAndDecode(JSAny? value) => null;

  @override
  JSAny? getProperty(JSObject object, String name) {
    if (identical(object, errorResult) && name == 'httpCode') {
      return httpCode.toJS;
    }
    if (identical(object, errorResult) && name == 'body') {
      return JSObject();
    }
    return null;
  }
}

final class _MissingAliasUserBridge implements MParticleJsBridge {
  final JSObject store = JSObject();
  final JSObject sdkConfig = JSObject();

  @override
  JSAny? callMethodVarArgs(JSObject object, String method, List<JSAny?> args) {
    if (method == 'getInstance') {
      return JSObject();
    }
    if (method == 'getUser') {
      return null;
    }
    return null;
  }

  @override
  JSObject requireCommerce({JSObject? mParticle}) => JSObject();

  @override
  JSObject requireConsent({JSObject? mParticle}) => JSObject();

  @override
  JSObject requireIdentity({JSObject? mParticle}) => JSObject();

  @override
  JSObject requireMParticle() => JSObject();

  @override
  JSObject requireMParticleReady() => JSObject();

  @override
  JSObject requireRokt({JSObject? mParticle}) => JSObject();

  @override
  Object? jsDartify(JSAny? value) => null;

  @override
  JSAny? jsifyValue(Object? value) => value?.toString().toJS;

  @override
  String jsStringify(JSAny? value) => '';

  @override
  Object? stringifyAndDecode(JSAny? value) => null;

  @override
  JSAny? getProperty(JSObject object, String name) {
    if (name == '_Store') {
      return store;
    }
    if (identical(object, store) && name == 'SDKConfig') {
      return sdkConfig;
    }
    if (identical(object, sdkConfig) && name == 'aliasMaxWindow') {
      return 90.toJS;
    }
    return null;
  }
}
