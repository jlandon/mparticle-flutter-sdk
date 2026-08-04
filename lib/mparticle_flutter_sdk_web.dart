// Maps the Flutter MethodChannel API to the mParticle JS SDK (Wasm-safe interop).

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:mparticle_flutter_sdk/src/web_helpers/analytics_web.dart'
    as analytics_web;
import 'package:mparticle_flutter_sdk/src/web_helpers/commerce_web.dart'
    as commerce_web;
import 'package:mparticle_flutter_sdk/src/web_helpers/consent_web.dart'
    as consent_web;
import 'package:mparticle_flutter_sdk/src/web_helpers/identity_web.dart'
    as identity_web;
import 'package:mparticle_flutter_sdk/src/web_helpers/js_bridge.dart';
import 'package:mparticle_flutter_sdk/src/web_helpers/user_web.dart'
    as user_web;

/// A web implementation of the MparticleFlutterSdk plugin.
class MparticleFlutterSdkWeb {
  MparticleFlutterSdkWeb({MParticleJsBridge? bridge})
      : _bridge = bridge ?? MParticleJsBridge.instance;

  final MParticleJsBridge _bridge;

  static void registerWith(Registrar registrar) {
    final channel = MethodChannel(
      'mparticle_flutter_sdk',
      const StandardMethodCodec(),
      registrar,
    );

    final pluginInstance = MparticleFlutterSdkWeb();
    channel.setMethodCallHandler(pluginInstance.handleMethodCall);
  }

  Future<dynamic> handleMethodCall(MethodCall call) async {
    try {
      return await _dispatch(call);
    } on PlatformException {
      rethrow;
    } catch (error) {
      throw PlatformException(
        code: MparticleWebErrorCodes.interopFailed,
        message: 'mParticle web interop failed for ${call.method}.',
        details: error.toString(),
      );
    }
  }

  Future<dynamic> _dispatch(MethodCall call) async {
    switch (call.method) {
      case 'isInitialized':
        try {
          return analytics_web.isInitialized(bridge: _bridge);
        } on PlatformException catch (error) {
          if (error.code == MparticleWebErrorCodes.snippetMissing) {
            rethrow;
          }
          throw PlatformException(
            code: MparticleWebErrorCodes.notReady,
            message:
                'Unable to get mParticle initialization status. Double-check '
                'your web API key and snippet configuration.',
            details: error.details ?? error.message,
          );
        } catch (error) {
          throw PlatformException(
            code: MparticleWebErrorCodes.notReady,
            message:
                'Unable to get mParticle initialization status. Double-check '
                'your web API key and snippet configuration.',
            details: error.toString(),
          );
        }

      case 'getAppName':
        return analytics_web.getAppName(bridge: _bridge);

      case 'logError':
        analytics_web.logError(
          bridge: _bridge,
          arguments: call.arguments as Map<dynamic, dynamic>,
        );
        return null;

      case 'logEvent':
        analytics_web.logEvent(
          bridge: _bridge,
          arguments: call.arguments as Map<dynamic, dynamic>,
        );
        return null;

      case 'logScreenEvent':
        analytics_web.logScreenEvent(
          bridge: _bridge,
          arguments: call.arguments as Map<dynamic, dynamic>,
        );
        return null;

      case 'setOptOut':
        analytics_web.setOptOut(
          bridge: _bridge,
          optOut: call.arguments['optOutBoolean'] as bool,
        );
        return null;

      case 'upload':
        analytics_web.upload(bridge: _bridge);
        return null;

      case 'getMPID':
        final ctx = MParticleWebContext.forCall(requireReady: true);
        return user_web.getMpid(
          bridge: _bridge,
          identity: ctx.identityNamespace,
        );

      case 'getUserAttributes':
        final ctx = MParticleWebContext.forCall(requireReady: true);
        return user_web.getUserAttributes(
          bridge: _bridge,
          identity: ctx.identityNamespace,
          mpid: call.arguments['mpid'] as String,
        );

      case 'getUserIdentities':
        final ctx = MParticleWebContext.forCall(requireReady: true);
        return user_web.getUserIdentities(
          bridge: _bridge,
          identity: ctx.identityNamespace,
          mpid: call.arguments['mpid'] as String,
        );

      case 'setUserAttribute':
        final ctx = MParticleWebContext.forCall(requireReady: true);
        user_web.setUserAttribute(
          bridge: _bridge,
          identity: ctx.identityNamespace,
          arguments: call.arguments as Map<dynamic, dynamic>,
        );
        return null;

      case 'removeUserAttribute':
        final ctx = MParticleWebContext.forCall(requireReady: true);
        user_web.removeUserAttribute(
          bridge: _bridge,
          identity: ctx.identityNamespace,
          arguments: call.arguments as Map<dynamic, dynamic>,
        );
        return null;

      case 'setUserAttributeArray':
        final ctx = MParticleWebContext.forCall(requireReady: true);
        user_web.setUserAttributeArray(
          bridge: _bridge,
          identity: ctx.identityNamespace,
          arguments: call.arguments as Map<dynamic, dynamic>,
        );
        return null;

      case 'setUserTag':
        final ctx = MParticleWebContext.forCall(requireReady: true);
        user_web.setUserTag(
          bridge: _bridge,
          identity: ctx.identityNamespace,
          arguments: call.arguments as Map<dynamic, dynamic>,
        );
        return null;

      case 'identify':
      case 'login':
      case 'logout':
      case 'modify':
        final ctx = MParticleWebContext.forCall(requireReady: true);
        return identity_web.sendIdentityCall(
          bridge: _bridge,
          identity: ctx.identityNamespace,
          identityMethod: call.method,
          identityRequestMap:
              call.arguments['identityRequest'] as Map<dynamic, dynamic>? ?? {},
        );

      case 'aliasUsers':
        final ctx = MParticleWebContext.forCall(requireReady: true);
        await identity_web.aliasUsers(
          bridge: _bridge,
          identity: ctx.identityNamespace,
          mParticle: ctx.mParticle,
          jsAliasRequest:
              call.arguments['aliasRequest'] as Map<dynamic, dynamic>,
        );
        return null;

      case 'logCommerceEvent':
        final ctx = MParticleWebContext.forCall(requireReady: true);
        return commerce_web.logCommerceEvent(
          bridge: _bridge,
          commerce: ctx.commerceNamespace,
          commerceEvent:
              call.arguments['commerceEvent'] as Map<dynamic, dynamic>,
        );

      case 'getGDPRConsentState':
        final ctx = MParticleWebContext.forCall(requireReady: true);
        return consent_web.getGdprConsentState(
          bridge: _bridge,
          identity: ctx.identityNamespace,
          mpid: call.arguments['mpid'] as String,
        );

      case 'addGDPRConsentState':
        final ctx = MParticleWebContext.forCall(requireReady: true);
        consent_web.addGdprConsentState(
          bridge: _bridge,
          identity: ctx.identityNamespace,
          consent: ctx.consentNamespace,
          arguments: call.arguments as Map<dynamic, dynamic>,
        );
        return null;

      case 'removeGDPRConsentState':
        final ctx = MParticleWebContext.forCall(requireReady: true);
        consent_web.removeGdprConsentState(
          bridge: _bridge,
          identity: ctx.identityNamespace,
          arguments: call.arguments as Map<dynamic, dynamic>,
        );
        return null;

      case 'getCCPAConsentState':
        final ctx = MParticleWebContext.forCall(requireReady: true);
        return consent_web.getCcpaConsentState(
          bridge: _bridge,
          identity: ctx.identityNamespace,
          mpid: call.arguments['mpid'] as String,
        );

      case 'addCCPAConsentState':
        final ctx = MParticleWebContext.forCall(requireReady: true);
        consent_web.addCcpaConsentState(
          bridge: _bridge,
          identity: ctx.identityNamespace,
          consent: ctx.consentNamespace,
          arguments: call.arguments as Map<dynamic, dynamic>,
        );
        return null;

      case 'removeCCPAConsentState':
        final ctx = MParticleWebContext.forCall(requireReady: true);
        consent_web.removeCcpaConsentState(
          bridge: _bridge,
          identity: ctx.identityNamespace,
          arguments: call.arguments as Map<dynamic, dynamic>,
        );
        return null;

      case 'roktSelectPlacements':
        final ctx = MParticleWebContext.forCall(requireReady: true);
        analytics_web.roktSelectPlacements(
          bridge: _bridge,
          rokt: ctx.roktNamespace,
          arguments: call.arguments as Map<dynamic, dynamic>,
        );
        return null;

      default:
        throw PlatformException(
          code: 'Unimplemented',
          details:
              'mParticle Flutter SDK for Web does not support \'${call.method}\'',
        );
    }
  }
}
