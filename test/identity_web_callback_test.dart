@TestOn('browser')
import 'dart:js_interop';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mparticle_flutter_sdk/src/web_helpers/identity_web.dart';
import 'package:mparticle_flutter_sdk/src/web_helpers/js_bridge.dart';
import 'package:mparticle_flutter_sdk/src/web_helpers/web_identity_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('invokeIdentityCallback times out when JS callback never fires', () {
    fakeAsync((async) {
      final bridge = _NonCompletingIdentityBridge();
      String? completedJson;
      invokeIdentityCallback(
        bridge: bridge,
        identity: JSObject(),
        identityMethod: 'identify',
        identityRequest: createWebIdentityRequest({7: 'test@example.com'}),
        timeout: const Duration(milliseconds: 50),
      ).then((value) => completedJson = value);

      expect(completedJson, isNull);
      async.elapse(const Duration(milliseconds: 50));
      async.flushMicrotasks();

      expect(completedJson, buildIdentityTimeoutJson());
      expect(bridge.identityMethodInvoked, 'identify');
    });
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
