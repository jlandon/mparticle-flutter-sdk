import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mparticle_flutter_sdk/identity/client_error_codes.dart';
import 'package:mparticle_flutter_sdk/identity/identity_api_error_response.dart';
import 'package:mparticle_flutter_sdk/identity/identity_api_result.dart';
import 'package:mparticle_flutter_sdk/identity/identity_type.dart';
import 'package:mparticle_flutter_sdk/src/identity/identity_helpers.dart'
    as mobile_identity;
import 'package:mparticle_flutter_sdk/src/web_helpers/commerce_helpers.dart';
import 'package:mparticle_flutter_sdk/src/web_helpers/web_identity_helpers.dart';

/// Golden matching: byte-for-byte for identity envelopes unless noted.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('convertIntIdentityToStringIdentity', () {
    test('maps known indices 0-21', () {
      expect(convertIntIdentityToStringIdentity(1), 'customerid');
      expect(convertIntIdentityToStringIdentity(7), 'email');
      expect(convertIntIdentityToStringIdentity(21), 'phone_number_3');
    });

    test('returns null for unknown index', () {
      expect(convertIntIdentityToStringIdentity(99), isNull);
    });
  });

  group('convertIdentityNameToStringifiedNumber', () {
    test('round-trips with int converter', () {
      for (var i = 0; i <= 21; i++) {
        if (i == 8) continue;
        final name = convertIntIdentityToStringIdentity(i);
        if (name != null) {
          expect(convertIdentityNameToStringifiedNumber(name), i.toString());
        }
      }
    });

    test('returns null for unknown name', () {
      expect(convertIdentityNameToStringifiedNumber('unknown'), isNull);
    });
  });

  group('createWebIdentityRequest', () {
    test('maps int keys to web identity names', () {
      final request =
          createWebIdentityRequest({7: 'test@example.com', 1: 'cid'});
      expect(request, {
        'userIdentities': {
          'email': 'test@example.com',
          'customerid': 'cid',
        },
      });
    });

    test('skips unknown identity indices', () {
      final request =
          createWebIdentityRequest({99: 'skip-me', 7: 'keep@example.com'});
      expect(request['userIdentities'], {'email': 'keep@example.com'});
    });
  });

  group('computeAliasWindow', () {
    test('uses now when endTime is null', () {
      const now = 1700000000000;
      const start = 1699000000000;
      final result = computeAliasWindow(
        nowMs: now,
        aliasMaxWindowDays: 90,
        startTime: start,
        endTime: null,
      );
      expect(result.endTime, now);
    });

    test('clamps start when outside alias window', () {
      const now = 1700000000000;
      const aliasDays = 90;
      const aliasMs = aliasDays * 24 * 60 * 60 * 1000;
      final result = computeAliasWindow(
        nowMs: now,
        aliasMaxWindowDays: aliasDays,
        startTime: now - aliasMs - 1000,
        endTime: now,
      );
      expect(result.startTime, now - aliasMs);
      expect(result.warnOutsideWindow, isFalse);
    });

    test('sets warnOutsideWindow when end precedes clamped start', () {
      const now = 1700000000000;
      const aliasDays = 90;
      const aliasMs = aliasDays * 24 * 60 * 60 * 1000;
      final result = computeAliasWindow(
        nowMs: now,
        aliasMaxWindowDays: aliasDays,
        startTime: now - aliasMs - 5000,
        endTime: now - aliasMs - 1000,
      );
      expect(result.startTime, now - aliasMs);
      expect(result.endTime, now - aliasMs - 1000);
      expect(result.warnOutsideWindow, isTrue);
    });
  });

  group('consent remapping', () {
    test('remapGdprConsentMap converts PascalCase keys', () {
      final mapped = remapGdprConsentMap({
        'marketing': {
          'Consented': true,
          'Document': 'doc',
          'Location': 'US',
          'HardwareId': 'hw',
          'Timestamp': 1234567890,
        },
      });
      expect(mapped['marketing'], {
        'consented': true,
        'document': 'doc',
        'location': 'US',
        'hardwareId': 'hw',
        'timestamp': 1234567890,
      });
    });

    test('remapCcpaConsentMap converts PascalCase keys', () {
      final mapped = remapCcpaConsentMap({
        'Consented': false,
        'Document': 'doc',
        'Location': 'CA',
        'HardwareId': 'hw',
        'Timestamp': 99,
      });
      expect(mapped, {
        'consented': false,
        'document': 'doc',
        'location': 'CA',
        'hardwareId': 'hw',
        'timestamp': 99,
      });
    });
  });

  group('buildIdentityResultJson', () {
    test('success includes previous_mpid except for modify', () {
      final json = jsonDecode(
        buildIdentityResultJson(
          httpCode: 200,
          mpid: 'mpid-1',
          previousMpid: 'prev-1',
          body: null,
          errors: null,
          identityMethod: 'identify',
        ),
      ) as Map<String, dynamic>;
      expect(json['previous_mpid'], 'prev-1');
    });

    test('modify omits previous_mpid', () {
      final json = jsonDecode(
        buildIdentityResultJson(
          httpCode: 200,
          mpid: 'mpid-1',
          previousMpid: 'prev-1',
          body: null,
          errors: null,
          identityMethod: 'modify',
        ),
      ) as Map<String, dynamic>;
      expect(json.containsKey('previous_mpid'), isFalse);
    });

    test('client error -1 sets http_code null and string code', () {
      final json = jsonDecode(
        buildIdentityResultJson(
          httpCode: -1,
          mpid: null,
          previousMpid: null,
          body: 'No connection',
          errors: null,
          identityMethod: 'identify',
        ),
      ) as Map<String, dynamic>;
      expect(json['http_code'], isNull);
      expect(json['errors'], [
        {'code': '-1', 'message': 'No connection'},
      ]);
    });

    test('matches identity_success golden fixture', () {
      final golden = _readFixture('identity_success.json');
      final built = buildIdentityResultJson(
        httpCode: 200,
        mpid: 'test-mpid-123',
        previousMpid: 'prev-mpid-456',
        body: null,
        errors: null,
        identityMethod: 'identify',
      );
      expect(jsonDecode(built), jsonDecode(golden));
    });

    test('400 with empty errors synthesizes failure envelope', () {
      final json = jsonDecode(
        buildIdentityResultJson(
          httpCode: 400,
          mpid: null,
          previousMpid: null,
          body: null,
          errors: [],
          identityMethod: 'identify',
        ),
      ) as Map<String, dynamic>;
      expect(json['http_code'], 400);
      expect(json['errors'], isNotEmpty);
    });

    test('synthesized 400 envelope fails sendIdentityRequest parser', () async {
      final envelope = buildIdentityResultJson(
        httpCode: 400,
        mpid: null,
        previousMpid: null,
        body: null,
        errors: [],
        identityMethod: 'identify',
      );
      final channel = MethodChannel('test-400-synth');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => envelope);

      await expectLater(
        mobile_identity.sendIdentityRequest(
          {IdentityType.Email: 'bad@example.com'},
          channel,
          'identify',
        ),
        throwsA(isA<IdentityAPIErrorResponse>().having(
          (e) => e.httpCode,
          'httpCode',
          400,
        )),
      );
    });

    test('500 normalizes body.errors list', () {
      final json = jsonDecode(
        buildIdentityResultJson(
          httpCode: 500,
          mpid: null,
          previousMpid: null,
          body: {
            'errors': [
              {'code': 'E500', 'message': 'server error'},
            ],
          },
          errors: null,
          identityMethod: 'identify',
        ),
      ) as Map<String, dynamic>;
      expect(json['errors'], [
        {'code': 'E500', 'message': 'server error'},
      ]);
    });

    test('unknown http code synthesizes fallback error', () {
      final json = jsonDecode(
        buildIdentityResultJson(
          httpCode: 403,
          mpid: null,
          previousMpid: null,
          body: 'Forbidden',
          errors: null,
          identityMethod: 'identify',
        ),
      ) as Map<String, dynamic>;
      expect(json['errors'], [
        {'code': '403', 'message': 'Forbidden'},
      ]);
    });

    test('timeout JSON matches client error shape', () {
      final json =
          jsonDecode(buildIdentityTimeoutJson()) as Map<String, dynamic>;
      expect(json['http_code'], isNull);
      expect(json['errors'], [
        {'code': '-1', 'message': 'Identity callback timed out'},
      ]);
    });
  });

  group('identitiesNameMapToStringKeyMap', () {
    test('converts identity names to stringified indices', () {
      final mapped = identitiesNameMapToStringKeyMap({
        'customerid': 'cid-1',
        'email': 'a@b.com',
      });
      expect(mapped, {'1': 'cid-1', '7': 'a@b.com'});
    });
  });

  group('buildProductCreateArgs', () {
    test('preserves nullable product fields', () {
      final args = buildProductCreateArgs({
        'name': 'Orange',
        'sku': 'sku-1',
        'price': 1.5,
        'quantity': 2,
        'variant': null,
        'category': 'produce',
        'brand': null,
        'position': 1,
        'couponCode': null,
        'attributes': null,
      });
      expect(args[0], 'Orange');
      expect(args[4], isNull);
      expect(args[9], isNull);
    });
  });

  group('parser integration', () {
    test('identity success golden parses to IdentityApiResult', () async {
      final golden = _readFixture('identity_success.json');
      final channel = MethodChannel('test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => golden);

      final result = await mobile_identity.sendIdentityRequest(
        {IdentityType.Email: 'test@example.com'},
        channel,
        'identify',
      );
      expect(result, isA<IdentityApiResult>());
      final apiResult = result as IdentityApiResult;
      expect(apiResult.user.getMPID(), 'test-mpid-123');
      expect(apiResult.previousUser?.getMPID(), 'prev-mpid-456');
    });

    test('identity 400 golden parses to IdentityAPIErrorResponse', () async {
      final golden = _readFixture('identity_400.json');
      final channel = MethodChannel('test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => golden);

      await expectLater(
        mobile_identity.sendIdentityRequest(
          {IdentityType.Email: 'bad@example.com'},
          channel,
          'identify',
        ),
        throwsA(isA<IdentityAPIErrorResponse>().having(
          (e) => e.httpCode,
          'httpCode',
          400,
        )),
      );
    });

    test('client error golden maps to ClientNoConnection on web', () async {
      final golden = _readFixture('identity_client_error.json');
      final channel = MethodChannel('test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => golden);

      await expectLater(
        mobile_identity.sendIdentityRequest(
          {IdentityType.Email: 'test@example.com'},
          channel,
          'identify',
        ),
        throwsA(isA<IdentityAPIErrorResponse>().having(
          (e) => e.clientErrorCode,
          'clientErrorCode',
          IdentityClientErrorCodes.ClientNoConnection,
        )),
      );
    });
  });

  group('convertDartErrorList', () {
    test('maps error objects to code/message maps', () {
      final errors = convertDartErrorList([
        {'code': 'E1', 'message': 'msg'},
      ]);
      expect(errors, [
        {'code': 'E1', 'message': 'msg'},
      ]);
    });
  });
}

String _readFixture(String name) {
  return File('test/fixtures/web/$name').readAsStringSync();
}
