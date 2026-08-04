@TestOn('browser')
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mparticle_flutter_sdk/mparticle_flutter_sdk.dart';
import 'package:mparticle_flutter_sdk/mparticle_flutter_sdk_web.dart';
import 'package:mparticle_flutter_sdk/src/web_helpers/js_bridge.dart';
import 'package:mparticle_flutter_sdk/src/web_helpers/mparticle_globals.dart';

import 'dart:js_interop';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MparticleFlutterSdkWeb isInitialized fail-closed', () {
    test('rethrows MP_WEB_SNIPPET_MISSING', () async {
      final plugin = MparticleFlutterSdkWeb(bridge: _SnippetMissingBridge());

      await expectLater(
        plugin.handleMethodCall(const MethodCall('isInitialized')),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            MparticleWebErrorCodes.snippetMissing,
          ),
        ),
      );
    });

    test('maps non-MP_WEB PlatformException to MP_WEB_NOT_READY', () async {
      final plugin = MparticleFlutterSdkWeb(
        bridge: _GenericPlatformExceptionBridge(),
      );

      await expectLater(
        plugin.handleMethodCall(const MethodCall('isInitialized')),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            MparticleWebErrorCodes.notReady,
          ),
        ),
      );
    });

    test('rethrows MP_WEB_INTEROP_FAILED from bridge', () async {
      final plugin = MparticleFlutterSdkWeb(
        bridge: _InteropPlatformExceptionBridge(),
      );

      await expectLater(
        plugin.handleMethodCall(const MethodCall('isInitialized')),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            MparticleWebErrorCodes.interopFailed,
          ),
        ),
      );
    });

    test('maps unexpected errors to MP_WEB_NOT_READY', () async {
      final plugin = MparticleFlutterSdkWeb(bridge: _ThrowingBridge());

      await expectLater(
        plugin.handleMethodCall(const MethodCall('isInitialized')),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            MparticleWebErrorCodes.notReady,
          ),
        ),
      );
    });
  });

  group('MparticleFlutterSdk.waitUntilReady (web)', () {
    const channel = MethodChannel('mparticle_flutter_sdk');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      MparticleFlutterSdk.resetForTest();
    });

    test(
      'rethrows MP_WEB_SNIPPET_MISSING without waiting for timeout',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'isInitialized') {
                throw PlatformException(
                  code: MparticleWebErrorCodes.snippetMissing,
                  message: 'snippet missing',
                );
              }
              return null;
            });
        MparticleFlutterSdk.resetForTest();

        await expectLater(
          MparticleFlutterSdk.waitUntilReady(
            timeout: const Duration(milliseconds: 200),
          ),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              MparticleWebErrorCodes.snippetMissing,
            ),
          ),
        );
      },
    );

    test('retries MP_WEB_NOT_READY then succeeds', () async {
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'isInitialized') {
              calls++;
              if (calls < 2) {
                throw PlatformException(
                  code: MparticleWebErrorCodes.notReady,
                  message: 'not ready',
                );
              }
              return true;
            }
            return null;
          });
      MparticleFlutterSdk.resetForTest();

      final sdk = await MparticleFlutterSdk.waitUntilReady(
        timeout: const Duration(seconds: 2),
      );
      expect(sdk, isA<MparticleFlutterSdk>());
      expect(calls, greaterThanOrEqualTo(2));
    });

    test('times out with MP_INIT_TIMEOUT when never ready', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'isInitialized') {
              throw PlatformException(
                code: MparticleWebErrorCodes.notReady,
                message: 'not ready',
              );
            }
            return null;
          });
      MparticleFlutterSdk.resetForTest();

      await expectLater(
        MparticleFlutterSdk.waitUntilReady(
          timeout: const Duration(milliseconds: 120),
        ),
        throwsA(
          isA<MparticleInitException>().having(
            (e) => e.code,
            'code',
            MparticleInitErrorCodes.timeout,
          ),
        ),
      );
    });
  });
}

final class _SnippetMissingBridge implements MParticleJsBridge {
  @override
  JSObject requireMParticle() {
    throw PlatformException(
      code: MparticleWebErrorCodes.snippetMissing,
      message: 'missing',
    );
  }

  @override
  JSObject requireMParticleReady() => requireMParticle();

  @override
  JSObject requireCommerce({JSObject? mParticle}) => JSObject();

  @override
  JSObject requireConsent({JSObject? mParticle}) => JSObject();

  @override
  JSObject requireIdentity({JSObject? mParticle}) => JSObject();

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
  JSAny? callMethodVarArgs(JSObject object, String method, List<JSAny?> args) =>
      null;

  @override
  JSAny? getProperty(JSObject object, String name) => null;
}

final class _GenericPlatformExceptionBridge implements MParticleJsBridge {
  @override
  JSObject requireMParticle() {
    throw PlatformException(code: 'CUSTOM_ERROR', message: 'not mp web');
  }

  @override
  JSObject requireMParticleReady() => requireMParticle();

  @override
  JSObject requireCommerce({JSObject? mParticle}) => JSObject();

  @override
  JSObject requireConsent({JSObject? mParticle}) => JSObject();

  @override
  JSObject requireIdentity({JSObject? mParticle}) => JSObject();

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
  JSAny? callMethodVarArgs(JSObject object, String method, List<JSAny?> args) =>
      null;

  @override
  JSAny? getProperty(JSObject object, String name) => null;
}

final class _InteropPlatformExceptionBridge implements MParticleJsBridge {
  @override
  JSObject requireMParticle() {
    throw PlatformException(
      code: MparticleWebErrorCodes.interopFailed,
      message: 'interop',
    );
  }

  @override
  JSObject requireMParticleReady() => requireMParticle();

  @override
  JSObject requireCommerce({JSObject? mParticle}) => JSObject();

  @override
  JSObject requireConsent({JSObject? mParticle}) => JSObject();

  @override
  JSObject requireIdentity({JSObject? mParticle}) => JSObject();

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
  JSAny? callMethodVarArgs(JSObject object, String method, List<JSAny?> args) =>
      null;

  @override
  JSAny? getProperty(JSObject object, String name) => null;
}

final class _ThrowingBridge implements MParticleJsBridge {
  @override
  JSObject requireMParticle() {
    throw StateError('unexpected');
  }

  @override
  JSObject requireMParticleReady() => requireMParticle();

  @override
  JSObject requireCommerce({JSObject? mParticle}) => JSObject();

  @override
  JSObject requireConsent({JSObject? mParticle}) => JSObject();

  @override
  JSObject requireIdentity({JSObject? mParticle}) => JSObject();

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
  JSAny? callMethodVarArgs(JSObject object, String method, List<JSAny?> args) =>
      null;

  @override
  JSAny? getProperty(JSObject object, String name) => null;
}
