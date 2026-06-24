import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mparticle_flutter_sdk/mparticle_flutter_sdk.dart';
import 'package:mparticle_flutter_sdk/events/event_type.dart';
import 'package:mparticle_flutter_sdk/events/mp_event.dart';
import 'package:mparticle_flutter_sdk/events/commerce_event.dart';
import 'package:mparticle_flutter_sdk/events/product.dart';
import 'package:mparticle_flutter_sdk/events/product_action_type.dart';
import 'package:mparticle_flutter_sdk/events/transaction_attributes.dart';
import 'package:mparticle_flutter_sdk/events/promotion.dart';
import 'package:mparticle_flutter_sdk/events/promotion_action_type.dart';
import 'package:mparticle_flutter_sdk/events/impression.dart';
import 'package:mparticle_flutter_sdk/events/screen_event.dart';
import 'package:mparticle_flutter_sdk/identity/alias_request.dart';
import 'package:mparticle_flutter_sdk/identity/identity_type.dart';
import 'package:mparticle_flutter_sdk/apple/authorization_status.dart';

void main() {
  const MethodChannel channel = MethodChannel('mparticle_flutter_sdk');
  MethodCall? methodCall;
  TestWidgetsFlutterBinding.ensureInitialized();

  MparticleFlutterSdk mp = MparticleFlutterSdk.testInstance();

  setUp(() async {
    MparticleFlutterSdk.resetForTest();
    mp = MparticleFlutterSdk.testInstance();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall call) async {
        methodCall = call;
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    methodCall = null;
    mp.clearPlaceholders();
    MparticleFlutterSdk.resetForTest();
  });

  group('initialize', () {
    test('toJson omits initTimeout and redacts toString', () {
      final options = MparticleOptions(
        apiKey: 'key',
        apiSecret: 'secret',
        logLevel: MparticleLogLevel.verbose,
      );
      expect(options.toJson().containsKey('initTimeout'), isFalse);
      expect(options.toString(), contains('[REDACTED]'));
      expect(options.toString(), isNot(contains('secret')));
    });

    test('empty credentials throw MP_INIT_INVALID_CREDENTIALS', () {
      expect(
        () => MparticleOptions(apiKey: ' ', apiSecret: 'x').validate(),
        throwsA(isA<MparticleInitException>().having(
          (e) => e.code,
          'code',
          MparticleInitErrorCodes.invalidCredentials,
        )),
      );
    });

    test('initialize invokes channel with wire payload', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall call) async {
          methodCall = call;
          if (call.method == 'initialize') {
            return null;
          }
          return null;
        },
      );

      MparticleFlutterSdk.resetForTest();
      final sdk = await MparticleFlutterSdk.initialize(
        MparticleOptions(apiKey: 'key', apiSecret: 'secret'),
      );
      expect(sdk, isNotNull);
      expect(methodCall?.method, 'initialize');
      expect(methodCall?.arguments['apiKey'], 'key');
    });

    test('invalid customBaseUrl throws MP_INIT_INVALID_BASE_URL', () {
      expect(
        () => MparticleOptions(
          apiKey: 'key',
          apiSecret: 'secret',
          customBaseUrl: 'http://insecure.example',
        ).validate(),
        throwsA(isA<MparticleInitException>().having(
          (e) => e.code,
          'code',
          MparticleInitErrorCodes.invalidBaseUrl,
        )),
      );
    });

    test('customBaseUrl without host throws MP_INIT_INVALID_BASE_URL', () {
      expect(
        () => MparticleOptions(
          apiKey: 'key',
          apiSecret: 'secret',
          customBaseUrl: 'https://',
        ).validate(),
        throwsA(isA<MparticleInitException>().having(
          (e) => e.code,
          'code',
          MparticleInitErrorCodes.invalidBaseUrl,
        )),
      );
    });

    test('valid customBaseUrl passes validate', () {
      expect(
        () => MparticleOptions(
          apiKey: 'key',
          apiSecret: 'secret',
          customBaseUrl: 'https://cdn.example.com',
        ).validate(),
        returnsNormally,
      );
    });

    test('logLevel wire indices serialize for non-default levels', () {
      expect(
        MparticleOptions(
          apiKey: 'key',
          apiSecret: 'secret',
          logLevel: MparticleLogLevel.verbose,
        ).toJson()['logLevel'],
        MparticleLogLevel.verbose.index,
      );
      expect(
        MparticleOptions(
          apiKey: 'key',
          apiSecret: 'secret',
          logLevel: MparticleLogLevel.info,
        ).toJson()['logLevel'],
        MparticleLogLevel.info.index,
      );
    });

    test('second initialize with same apiKey returns same instance', () async {
      var initCallCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall call) async {
          if (call.method == 'initialize') {
            initCallCount++;
            return null;
          }
          return null;
        },
      );

      MparticleFlutterSdk.resetForTest();
      final options = MparticleOptions(apiKey: 'key-a', apiSecret: 'secret');
      final first = await MparticleFlutterSdk.initialize(options);
      final second = await MparticleFlutterSdk.initialize(options);

      expect(identical(first, second), isTrue);
      expect(initCallCount, 1);
    });

    test('concurrent initialize success coalesces to one instance', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall call) async {
          if (call.method == 'initialize') {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            return null;
          }
          return null;
        },
      );

      MparticleFlutterSdk.resetForTest();
      final options = MparticleOptions(apiKey: 'key', apiSecret: 'secret');
      final first = MparticleFlutterSdk.initialize(options);
      final second = MparticleFlutterSdk.initialize(options);
      final results = await Future.wait([first, second]);

      expect(identical(results[0], results[1]), isTrue);
    });

    test('in-flight initialize with different apiKey throws already started',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall call) async {
          if (call.method == 'initialize') {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return null;
          }
          return null;
        },
      );

      MparticleFlutterSdk.resetForTest();
      final first = MparticleFlutterSdk.initialize(
        MparticleOptions(apiKey: 'key-a', apiSecret: 'secret'),
      );

      await expectLater(
        MparticleFlutterSdk.initialize(
          MparticleOptions(apiKey: 'key-b', apiSecret: 'secret'),
        ),
        throwsA(isA<MparticleAlreadyInitializedException>()),
      );

      await first;
    });

    test('bootstrapIdentityRequest rejects more than ten identities', () {
      final identities = {
        for (var i = 0; i < 11; i++)
          IdentityType.values[i % IdentityType.values.length]: 'id-$i',
      };
      expect(
        () => MparticleOptions(
          apiKey: 'key',
          apiSecret: 'secret',
          bootstrapIdentityRequest: identities,
        ).validate(),
        throwsA(isA<MparticleInitException>().having(
          (e) => e.code,
          'code',
          MparticleInitErrorCodes.invalidOptions,
        )),
      );
    });

    test('bootstrapIdentityRequest rejects empty identity values', () {
      expect(
        () => MparticleOptions(
          apiKey: 'key',
          apiSecret: 'secret',
          bootstrapIdentityRequest: {IdentityType.Email: '  '},
        ).validate(),
        throwsA(isA<MparticleInitException>().having(
          (e) => e.code,
          'code',
          MparticleInitErrorCodes.invalidOptions,
        )),
      );
    });

    test('bootstrapIdentityRequest rejects values over 256 characters', () {
      expect(
        () => MparticleOptions(
          apiKey: 'key',
          apiSecret: 'secret',
          bootstrapIdentityRequest: {
            IdentityType.Email: 'x' * 257,
          },
        ).validate(),
        throwsA(isA<MparticleInitException>().having(
          (e) => e.code,
          'code',
          MparticleInitErrorCodes.invalidOptions,
        )),
      );
    });

    test('invalid urlScheme throws MP_INIT_INVALID_OPTIONS', () {
      expect(
        () => MparticleOptions(
          apiKey: 'key',
          apiSecret: 'secret',
          ios: IOSOptions(
            roktPaymentExtension: RoktPaymentExtensionOptions(
              applePayMerchantId: 'merchant.com.example',
              urlScheme: '123-invalid',
            ),
          ),
        ).validate(),
        throwsA(isA<MparticleInitException>().having(
          (e) => e.code,
          'code',
          MparticleInitErrorCodes.invalidOptions,
        )),
      );
    });

    test('initTimeout is clamped between 1 and 30 seconds', () {
      final short = MparticleOptions(
        apiKey: 'key',
        apiSecret: 'secret',
        initTimeout: const Duration(milliseconds: 500),
      );
      final long = MparticleOptions(
        apiKey: 'key',
        apiSecret: 'secret',
        initTimeout: const Duration(seconds: 60),
      );
      expect(short.initTimeout, const Duration(seconds: 1));
      expect(long.initTimeout, const Duration(seconds: 30));
    });

    test('bootstrapIdentityRequest serializes identity indices', () {
      final json = MparticleOptions(
        apiKey: 'key',
        apiSecret: 'secret',
        bootstrapIdentityRequest: {IdentityType.Email: 'test@example.com'},
      ).toJson();
      expect(
        json['bootstrapIdentityRequest'],
        {
          'identities': {
            IdentityType.Email.index.toString(): 'test@example.com'
          }
        },
      );
    });

    test('mapInitExceptionFromPlatform preserves native message', () {
      final mapped = mapInitExceptionFromPlatform(
        PlatformException(
          code: MparticleInitErrorCodes.invalidOptions,
          message: 'Application context unavailable',
        ),
      );
      expect(mapped.message, 'Application context unavailable');
    });

    test('instance throws StateError before initialize completes', () {
      MparticleFlutterSdk.resetForTest();
      expect(() => MparticleFlutterSdk.instance, throwsStateError);
    });

    test('waitUntilReady throws StateError on mobile before initialize',
        () async {
      MparticleFlutterSdk.resetForTest();
      await expectLater(
        MparticleFlutterSdk.waitUntilReady(),
        throwsA(isA<StateError>()),
      );
    });

    test('second initialize with different apiKey throws already started',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall call) async {
          if (call.method == 'initialize') {
            return null;
          }
          return null;
        },
      );

      MparticleFlutterSdk.resetForTest();
      await MparticleFlutterSdk.initialize(
        MparticleOptions(apiKey: 'key-a', apiSecret: 'secret'),
      );

      await expectLater(
        MparticleFlutterSdk.initialize(
          MparticleOptions(apiKey: 'key-b', apiSecret: 'secret'),
        ),
        throwsA(isA<MparticleAlreadyInitializedException>()),
      );
    });

    test(
        'concurrent initialize waiters receive typed init exception on native failure',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall call) async {
          if (call.method == 'initialize') {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            throw PlatformException(
              code: MparticleInitErrorCodes.invalidOptions,
              message: 'native failure',
            );
          }
          return null;
        },
      );

      MparticleFlutterSdk.resetForTest();
      final options = MparticleOptions(apiKey: 'key', apiSecret: 'secret');
      final first = MparticleFlutterSdk.initialize(options);
      final second = MparticleFlutterSdk.initialize(options);

      await expectLater(
        first,
        throwsA(isA<MparticleInitException>().having(
          (e) => e.code,
          'code',
          MparticleInitErrorCodes.invalidOptions,
        )),
      );
      await expectLater(
        second,
        throwsA(isA<MparticleInitException>().having(
          (e) => e.code,
          'code',
          MparticleInitErrorCodes.invalidOptions,
        )),
      );
    });

    test('initialize timeout throws MP_INIT_TIMEOUT', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall call) async {
          if (call.method == 'initialize') {
            await Future<void>.delayed(const Duration(seconds: 2));
          }
          return null;
        },
      );

      MparticleFlutterSdk.resetForTest();
      await expectLater(
        MparticleFlutterSdk.initialize(
          MparticleOptions(
            apiKey: 'key',
            apiSecret: 'secret',
            initTimeout: const Duration(seconds: 1),
          ),
        ),
        throwsA(isA<MparticleInitException>().having(
          (e) => e.code,
          'code',
          MparticleInitErrorCodes.timeout,
        )),
      );
    });

    test(
        'platform already started maps to MparticleAlreadyInitializedException',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall call) async {
          if (call.method == 'initialize') {
            throw PlatformException(
              code: MparticleInitErrorCodes.alreadyStarted,
              message: 'already started',
            );
          }
          return null;
        },
      );

      MparticleFlutterSdk.resetForTest();
      await expectLater(
        MparticleFlutterSdk.initialize(
          MparticleOptions(apiKey: 'key', apiSecret: 'secret'),
        ),
        throwsA(isA<MparticleAlreadyInitializedException>().having(
          (e) => e.message,
          'message',
          'already started',
        )),
      );
    });

    test('native init conflict preserves AppDelegate migration message',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall call) async {
          if (call.method == 'initialize') {
            throw PlatformException(
              code: MparticleInitErrorCodes.alreadyStarted,
              message:
                  'mParticle already initialized natively; remove AppDelegate start before Dart initialize()',
            );
          }
          return null;
        },
      );

      MparticleFlutterSdk.resetForTest();
      await expectLater(
        MparticleFlutterSdk.initialize(
          MparticleOptions(apiKey: 'key', apiSecret: 'secret'),
        ),
        throwsA(isA<MparticleAlreadyInitializedException>().having(
          (e) => e.message,
          'message',
          contains('AppDelegate'),
        )),
      );
    });
  });

  group('mParticle Dart API Layer', () {
    test('logEvent', () async {
      MPEvent event =
          MPEvent(eventName: 'Clicked Search Bar', eventType: EventType.Search)
            ..customAttributes = {'key1': 'value1'}
            ..customFlags = {'flag1': 'value1'};

      await mp.logEvent(event);
      expect(
        methodCall,
        isMethodCall(
          'logEvent',
          arguments: {
            'eventName': 'Clicked Search Bar',
            'eventType': 3,
            'customAttributes': {'key1': 'value1'},
            'customFlags': {'flag1': 'value1'},
            'shouldUploadEvent': null
          },
        ),
      );
    });

    test('log product action commerce event', () async {
      final Product product1 =
          Product(name: 'Orange', sku: '123abc', price: 5.0, quantity: 1);
      final Product product2 =
          Product(name: 'Apple', sku: '456abc', price: 10.5, quantity: 2);
      final TransactionAttributes transactionAttributes = TransactionAttributes(
          transactionId: '123456',
          affiliation: 'affiliation',
          couponCode: '12412342',
          shipping: 1.34,
          tax: 43.232,
          revenue: 242.2);
      CommerceEvent commerceEvent = CommerceEvent.withProduct(
          productActionType: ProductActionType.Purchase, product: product1)
        ..products.add(product2)
        ..transactionAttributes = transactionAttributes
        ..currency = 'US'
        ..screenName = 'One Click Purchase';
      mp.logCommerceEvent(commerceEvent);
      expect(
        methodCall,
        isMethodCall(
          'logCommerceEvent',
          arguments: {
            'commerceEvent': {
              'products': [product1.toJson(), product2.toJson()],
              'promotions': [],
              'impressions': [],
              'transactionAttributes': transactionAttributes.toJson(),
              'checkoutOptions': null,
              'currency': 'US',
              'productListName': null,
              'productListSource': null,
              'screenName': 'One Click Purchase',
              'checkoutStep': null,
              'nonInteractive': null,
              'shouldUploadEvent': null,
              'customAttributes': null,
              'customFlags': null,
              'productActionType': 8,
              'jsProductActionType': 6,
              'androidProductActionType': 'purchase',
            }
          },
        ),
      );
    });

    test('log promotion commerce event', () async {
      final Promotion promotion1 = Promotion(
          promotionId: '12312',
          creative: 'Jennifer Slater',
          name: 'BOGO Bonanza',
          position: 'top');
      final Promotion promotion2 = Promotion(
          promotionId: '15632',
          creative: 'Gregor Roman',
          name: 'Eco Living',
          position: 'mid');

      CommerceEvent commerceEvent = CommerceEvent.withPromotion(
          promotionActionType: PromotionActionType.View, promotion: promotion1)
        ..promotions.add(promotion2)
        ..currency = 'US'
        ..screenName = 'Promotion Screen Name';
      mp.logCommerceEvent(commerceEvent);
      expect(
        methodCall,
        isMethodCall(
          'logCommerceEvent',
          arguments: {
            'commerceEvent': {
              'products': [],
              'promotions': [
                {
                  'promotionId': '12312',
                  'creative': 'Jennifer Slater',
                  'name': 'BOGO Bonanza',
                  'position': 'top'
                },
                {
                  'promotionId': '15632',
                  'creative': 'Gregor Roman',
                  'name': 'Eco Living',
                  'position': 'mid'
                }
              ],
              'impressions': [],
              'transactionAttributes': null,
              'checkoutOptions': null,
              'currency': 'US',
              'productListName': null,
              'productListSource': null,
              'screenName': 'Promotion Screen Name',
              'checkoutStep': null,
              'nonInteractive': null,
              'shouldUploadEvent': null,
              'customAttributes': null,
              'customFlags': null,
              'promotionActionType': 1,
              'androidPromotionActionType': 'view',
              'jsPromotionActionType': 1
            }
          },
        ),
      );
    });

    test('log impression commerce event', () async {
      final Product product1 =
          Product(name: 'Orange', sku: '123abc', price: 2.4, quantity: 1);
      final Impression impression1 =
          Impression(impressionListName: 'produce', products: [product1]);
      final Impression impression2 =
          Impression(impressionListName: 'citrus', products: [product1]);
      CommerceEvent commerceEvent =
          CommerceEvent.withImpression(impression: impression1)
            ..impressions.add(impression2)
            ..currency = 'US'
            ..screenName = 'One Click Purchase';
      mp.logCommerceEvent(commerceEvent);
      expect(
        methodCall,
        isMethodCall(
          'logCommerceEvent',
          arguments: {
            'commerceEvent': {
              'products': [],
              'promotions': [],
              'impressions': [impression1.toJson(), impression2.toJson()],
              'transactionAttributes': null,
              'checkoutOptions': null,
              'currency': 'US',
              'productListName': null,
              'productListSource': null,
              'screenName': 'One Click Purchase',
              'checkoutStep': null,
              'nonInteractive': null,
              'shouldUploadEvent': null,
              'customAttributes': null,
              'customFlags': null,
            }
          },
        ),
      );
    });

    test('log error', () async {
      mp.logError(eventName: 'Error', customAttributes: {'key1': 'value1'});

      expect(
        methodCall,
        isMethodCall('logError', arguments: {
          'eventName': 'Error',
          'customAttributes': {'key1': 'value1'},
        }),
      );
    });

    test('log push registration', () async {
      mp.logPushRegistration(
          pushToken: 'pushToken123', senderId: 'senderId123');

      expect(
        methodCall,
        isMethodCall('logPushRegistration', arguments: {
          'pushToken': 'pushToken123',
          'senderId': 'senderId123',
        }),
      );
    });

    test('log screen event', () async {
      ScreenEvent screenEvent = ScreenEvent(eventName: 'Screen event logged')
        ..customAttributes = {'key1': 'value1'}
        ..customFlags = {'flag1': 'value1'};
      mp.logScreenEvent(screenEvent);

      expect(
        methodCall,
        isMethodCall('logScreenEvent', arguments: {
          'eventName': 'Screen event logged',
          'customAttributes': {'key1': 'value1'},
          'customFlags': {'flag1': 'value1'},
        }),
      );
    });

    test('set att status', () async {
      mp.setATTStatus(
          attStatus: MPATTAuthorizationStatus.Authorized,
          timestampInMillis: 1000);
      expect(
        methodCall,
        isMethodCall('setATTStatus',
            arguments: {'attStatus': 3, 'timestampInMillis': 1000}),
      );
    });

    test('set opt out', () async {
      mp.setOptOut(true);
      expect(
        methodCall,
        isMethodCall('setOptOut', arguments: {'optOutBoolean': true}),
      );
    });

    test('upload', () async {
      mp.upload();
      expect(
        methodCall,
        isMethodCall('upload', arguments: null),
      );
    });

    test('alias users', () async {
      var userAliasRequest = AliasRequest(
          sourceMpid: 'sourceMPID', destinationMpid: 'destinationMPID');
      userAliasRequest.setStartTime(123);
      userAliasRequest.setEndTime(456);
      mp.identity.aliasUsers(aliasRequest: userAliasRequest);
      expect(
        methodCall,
        isMethodCall('aliasUsers', arguments: {
          "aliasRequest": {
            'sourceMpid': 'sourceMPID',
            'destinationMpid': 'destinationMPID',
            'startTime': 123,
            'endTime': 456,
          }
        }),
      );
    });
  });

  group('Identity API', () {
    test('identify with identityRequest', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall call) async {
          methodCall = call;
          return '{"mpid": "123"}';
        },
      );

      IdentityRequest request = IdentityRequest()
        ..setIdentity(
            identityType: IdentityType.Email, value: 'test@example.com');
      await mp.identity.identify(identityRequest: request);
      expect(
        methodCall,
        isMethodCall('identify', arguments: {
          'identityRequest': {7: 'test@example.com'}
        }),
      );
    });

    test('identify without identityRequest sends empty map', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall call) async {
          methodCall = call;
          return '{"mpid": "123"}';
        },
      );

      await mp.identity.identify();
      expect(
        methodCall,
        isMethodCall('identify', arguments: {'identityRequest': {}}),
      );
    });

    test('login with identityRequest', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall call) async {
          methodCall = call;
          return '{"mpid": "123"}';
        },
      );
      IdentityRequest request = IdentityRequest()
        ..setIdentity(
            identityType: IdentityType.Email, value: 'login@example.com');
      await mp.identity.login(identityRequest: request);
      expect(
        methodCall,
        isMethodCall('login', arguments: {
          'identityRequest': {7: 'login@example.com'}
        }),
      );
    });

    test('login without identityRequest sends empty map', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall call) async {
          methodCall = call;
          return '{"mpid": "123"}';
        },
      );

      await mp.identity.login();
      expect(
        methodCall,
        isMethodCall('login', arguments: {'identityRequest': {}}),
      );
    });

    test('logout without identityRequest sends empty map', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall call) async {
          methodCall = call;
          return '{"mpid": "123"}';
        },
      );

      await mp.identity.logout();
      expect(
        methodCall,
        isMethodCall('logout', arguments: {'identityRequest': {}}),
      );
    });

    test('modify with identityRequest', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall call) async {
          methodCall = call;
          return '{"mpid": "123"}';
        },
      );

      IdentityRequest request = IdentityRequest()
        ..setIdentity(
            identityType: IdentityType.Email, value: 'new@example.com');
      await mp.identity.modify(identityRequest: request);
      expect(
        methodCall,
        isMethodCall('modify', arguments: {
          'identityRequest': {7: 'new@example.com'}
        }),
      );
    });

    test('logout with identityRequest', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall call) async {
          methodCall = call;
          return '{"mpid": "123"}';
        },
      );

      IdentityRequest request = IdentityRequest()
        ..setIdentity(identityType: IdentityType.CustomerId, value: 'user-123');
      await mp.identity.logout(identityRequest: request);
      expect(
        methodCall,
        isMethodCall('logout', arguments: {
          'identityRequest': {1: 'user-123'}
        }),
      );
    });
  });

  group('Rokt API', () {
    test('rokt select placements', () async {
      final roktConfig = RoktConfig(
          colorMode: ColorMode.dark,
          cacheConfig: CacheConfig(
              cacheDurationInSeconds: 100,
              cacheAttributes: {'key1': 'value1'}));
      await mp.rokt.selectPlacements(
          identifier: 'placement1',
          attributes: {'attr1': 'val1'},
          roktConfig: roktConfig,
          fontFilePathMap: {'font1': 'path1'});

      expect(
          methodCall,
          isMethodCall('roktSelectPlacements', arguments: {
            'placementId': 'placement1',
            'attributes': {'attr1': 'val1'},
            'config': {
              'colorMode': 'dark',
              'cacheConfig': {
                'cacheDurationInSeconds': 100,
                'cacheAttributes': {'key1': 'value1'}
              }
            },
            'fontFilePathMap': {'font1': 'path1'},
          }));
    });

    test('rokt select placements with placeholders', () async {
      mp.attachPlaceholder(id: 1, name: "placeholder1");
      await mp.rokt.selectPlacements(
        identifier: 'placement1',
      );

      expect(
          methodCall,
          isMethodCall('roktSelectPlacements', arguments: {
            'placementId': 'placement1',
            'attributes': null,
            'config': null,
            'fontFilePathMap': null,
            'placeholders': {1: 'placeholder1'},
          }));
    });

    test('rokt purchase finalized', () async {
      await mp.rokt.purchaseFinalized(
          placementId: 'placement1', catalogItemId: 'catalog1', success: true);

      expect(
          methodCall,
          isMethodCall('roktPurchaseFinalized', arguments: {
            'placementId': 'placement1',
            'catalogItemId': 'catalog1',
            'success': true,
          }));
    });

    test('rokt select shoppable ads', () async {
      final roktConfig = RoktConfig(
          colorMode: ColorMode.dark,
          cacheConfig: CacheConfig(
              cacheDurationInSeconds: 100,
              cacheAttributes: {'key1': 'value1'}));

      await mp.rokt.selectShoppableAds(
        identifier: 'identifier1',
        attributes: {'attr1': 'val1'},
        roktConfig: roktConfig,
      );

      expect(
          methodCall,
          isMethodCall('roktSelectShoppableAds', arguments: {
            'identifier': 'identifier1',
            'attributes': {'attr1': 'val1'},
            'config': {
              'colorMode': 'dark',
              'cacheConfig': {
                'cacheDurationInSeconds': 100,
                'cacheAttributes': {'key1': 'value1'}
              }
            },
          }));
    });
  });
}
