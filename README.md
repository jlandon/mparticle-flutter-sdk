# mparticle_flutter_sdk

Flutter allows developers to use a single code base to deploy to multiple platforms. Now, with the mParticle Flutter Plugin, you can leverage a single API to deploy your data to hundreds of integrations from your iOS, Android, and Web apps.

See the table below to see what features are currently supported

### Supported Features

| Method        | Android | iOS | Web | Notes |
| ------------- | ------- | --- | --- | ----- |
| Custom Events | X       | X   | X   |       |
| Page Views    | X       | X   | X   |       |
| Identity      | X       | X   | X   |       |
| eCommerce     | X       | X   | X   |       |
| Consent       | X       | X   | X   |       |

## Installation

1. Add the Flutter SDK as a dependency to your Flutter application:

```bash
flutter pub add mparticle_flutter_sdk
```

Specifying this dependency adds a line like the following to your package's `pubspec.yaml`:

```bash
dependencies:
    mparticle_flutter_sdk: ^3.0.0-beta.1
```

2.  Import the package into your Dart code:

```bash
import 'package:mparticle_flutter_sdk/mparticle_flutter_sdk.dart'
```

Now initialize mParticle from Dart. Native Gradle, Podfile, Application, and AppDelegate setup is **not required** for Android/iOS (Rokt kits are bundled in the plugin).

### Mobile (Android & iOS)

1. Add your mParticle key and secret from [your workspace dashboard](https://app.mparticle.com/setup/inputs/apps).
2. Call `MparticleFlutterSdk.initialize()` before `runApp()`:

```dart
import 'package:flutter/widgets.dart';
import 'package:mparticle_flutter_sdk/mparticle_flutter_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final mp = await MparticleFlutterSdk.initialize(
    MparticleOptions(
      apiKey: const String.fromEnvironment('MP_API_KEY'),
      apiSecret: const String.fromEnvironment('MP_API_SECRET'),
      logLevel: MparticleLogLevel.warning,
      customBaseUrl: null, // optional HTTPS CNAME
      ios: IOSOptions(
        roktPaymentExtension: RoktPaymentExtensionOptions(
          applePayMerchantId: 'merchant.com.example.app',
        ),
      ),
    ),
  );

  runApp(MyApp(mp: mp));
}
```

Run with credentials:

```bash
flutter run \
  --dart-define=MP_API_KEY=YOUR_KEY \
  --dart-define=MP_API_SECRET=YOUR_SECRET
```

**Android Rokt events:** extend `FlutterFragmentActivity` for your `MainActivity`:

```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

**Rokt bundle:** all apps inherit Rokt native dependencies (~1–2 MB Android APK impact).

Requires **Flutter ≥ 3.44.0** for Swift Package Manager support on iOS.

#### Initialization errors

`initialize()` throws [MparticleInitException] with stable [MparticleInitErrorCodes] values:

| Code                           | Where raised       | When                                                                             | Action                                               |
| ------------------------------ | ------------------ | -------------------------------------------------------------------------------- | ---------------------------------------------------- |
| `MP_INIT_INVALID_CREDENTIALS`  | Dart, Android, iOS | Empty `apiKey` / `apiSecret`                                                     | Pass non-empty credentials                           |
| `MP_INIT_INVALID_BASE_URL`     | Dart, Android, iOS | `customBaseUrl` not HTTPS or not parseable                                       | Fix CNAME URL                                        |
| `MP_INIT_INVALID_OPTIONS`      | Dart, Android, iOS | Invalid bootstrap identities, urlScheme, or native start failure                 | Fix options; check logcat/Xcode                      |
| `MP_INIT_ALREADY_STARTED`      | Dart, Android, iOS | Second init with different key, or legacy native init still present              | Use one init path; remove native `MParticle.start()` |
| `MP_INIT_TIMEOUT`              | Dart               | Method channel did not complete within `initTimeout` (default 5s, clamped 1–30s) | Increase `initTimeout` or fix native startup         |
| `MP_INIT_UNSUPPORTED_PLATFORM` | Dart               | `initialize()` on web                                                            | Use JS snippet + `waitUntilReady()`                  |

```dart
try {
  await MparticleFlutterSdk.initialize(options);
} on MparticleAlreadyInitializedException catch (e) {
  // Second init, legacy native init, or hot restart — e.message has native detail
} on MparticleInitException catch (e) {
  print('Init failed: ${e.code} — ${e.message}');
}
```

#### MparticleOptions reference

- `initTimeout` — Dart-only guard around the native init call (default 5 seconds; clamped to 1–30 seconds). Not sent over the method channel.
- `bootstrapIdentityRequest` — optional startup identify (max **10** identities, max **256** characters per value). Adds latency before `runApp()`; prefer `identity.identify()` after startup when possible.
- `logLevel` — on iOS, `MparticleLogLevel.info` maps to native Debug because the Apple SDK has no INFO level; `info` and `debug` both use Debug on iOS.
- `customBaseUrl` — must be HTTPS with a valid host (validated in Dart and on native platforms).
- **Hot restart:** if `initialize()` returns `MP_INIT_ALREADY_STARTED` after a hot restart, perform a full app restart — the native SDK remains initialized while Dart state was reset.

See [MIGRATING.md](./MIGRATING.md) for the 2.x → 3.0 upgrade guide.

### <a name="Web"></a>Web

Add the mParticle snippet to your `web/index.html` file as high as possible on the page within the <head> tag, per our [Web Docs](https://docs.mparticle.com/developers/sdk/web/getting-started/).

```html
<script type="text/javascript">
  //configure the SDK
  window.mParticle = {
      config: {
          isDevelopmentMode: true,
          identifyRequest: {
              userIdentities: {
                  email: 'email@example.com',
                  customerid: '123456',
              },
          },
          identityCallback: (response) {
              console.log(response);
          },
          dataPlan: {
            planId: 'my_plan_id',
            planVersion: 2
          }
      },
  };

  //load the SDK
  (
  function(t){window.mParticle=window.mParticle||{};window.mParticle.EventType={Unknown:0,Navigation:1,Location:2,Search:3,Transaction:4,UserContent:5,UserPreference:6,Social:7,Other:8};window.mParticle.eCommerce={Cart:{}};window.mParticle.Identity={};window.mParticle.config=window.mParticle.config||{};window.mParticle.config.rq=[];window.mParticle.config.snippetVersion=2.3;window.mParticle.ready=function(t){window.mParticle.config.rq.push(t)};var e=["endSession","logError","logBaseEvent","logEvent","logForm","logLink","logPageView","setSessionAttribute","setAppName","setAppVersion","setOptOut","setPosition","startNewSession","startTrackingLocation","stopTrackingLocation"];var o=["setCurrencyCode","logCheckout"];var i=["identify","login","logout","modify"];e.forEach(function(t){window.mParticle[t]=n(t)});o.forEach(function(t){window.mParticle.eCommerce[t]=n(t,"eCommerce")});i.forEach(function(t){window.mParticle.Identity[t]=n(t,"Identity")});function n(e,o){return function(){if(o){e=o+"."+e}var t=Array.prototype.slice.call(arguments);t.unshift(e);window.mParticle.config.rq.push(t)}}var dpId,dpV,config=window.mParticle.config,env=config.isDevelopmentMode?1:0,dbUrl="?env="+env,dataPlan=window.mParticle.config.dataPlan;dataPlan&&(dpId=dataPlan.planId,dpV=dataPlan.planVersion,dpId&&(dpV&&(dpV<1||dpV>1e3)&&(dpV=null),dbUrl+="&plan_id="+dpId+(dpV?"&plan_version="+dpV:"")));var mp=document.createElement("script");mp.type="text/javascript";mp.async=true;mp.src=("https:"==document.location.protocol?"https://jssdkcdns":"http://jssdkcdn")+".mparticle.com/js/v2/"+t+"/mparticle.js" + dbUrl;var c=document.getElementsByTagName("script")[0];c.parentNode.insertBefore(mp,c)}
  )("REPLACE WITH API KEY");
</script>
```

For more help, see the [full Web set up docs](https://docs.mparticle.com/developers/sdk/web/getting-started/#create-an-input).

After the snippet loads, call `await MparticleFlutterSdk.waitUntilReady()` from Dart (do **not** call `initialize()` on web). Optional `timeout` (default 5 seconds) throws `MparticleInitException` with code `MP_INIT_TIMEOUT` when the JS SDK never reports ready.

On mobile, `waitUntilReady()` throws `StateError` — use `initialize()` instead.

## Usage

Each of our Dart methods is mapped to an underlying mParticle SDK at the platform level. Note that per Dart's [documentation](https://flutter.dev/docs/development/platform-integration/platform-channels#architecture, calling into platform specific code is asynchronous to ensure the user interface remains responsive. In your code, you can swap usage between `async` and `then` in accordance to your app's requirements.

For a full description of all classes, methods, and properties, see the [mParticle Flutter SDK API Reference](https://pub.dev/documentation/mparticle_flutter_sdk/latest/).

### Import

**Importing** the module:

```dart
import 'package:mparticle_flutter_sdk/mparticle_flutter_sdk.dart';
```

Call `MparticleFlutterSdk.initialize()` on Android/iOS (or `waitUntilReady()` on web after the JS snippet) before other SDK methods.

```dart
final mpInstance = await MparticleFlutterSdk.initialize(
  MparticleOptions(
    apiKey: 'YOUR_KEY',
    apiSecret: 'YOUR_SECRET',
  ),
);
```

### Rokt

`Rokt` is exposed under `mpInstance?.rokt` and supports:

- `Future<void> events(String identifier, void Function(dynamic event) onEvent)` — await before `selectPlacements`
- `selectPlacements(...)`
- `selectShoppableAds(...)` (iOS implementation; Android no-op for parity; web unsupported)
- `purchaseFinalized(...)` (iOS)

Subscribe to events for a placement identifier before selecting placements:

```dart
await mpInstance?.rokt.events('MSDKEmbeddedLayout', (event) {
  print('Rokt event: $event');
});

await mpInstance?.rokt.selectPlacements(
  identifier: 'MSDKEmbeddedLayout',
  attributes: {'email': 'user@example.com'},
);
```

For iOS shoppable ads:

```dart
await mpInstance?.rokt.events('StgRoktShoppableAds', (event) {
  print('Rokt shoppable event: $event');
});

await mpInstance?.rokt.selectShoppableAds(
  identifier: 'StgRoktShoppableAds',
  attributes: {'email': 'user@example.com'},
);
```

To enable iOS payment flows for shoppable ads, pass `IOSOptions.roktPaymentExtension` to `initialize()`:

```dart
await MparticleFlutterSdk.initialize(
  MparticleOptions(
    apiKey: 'YOUR_KEY',
    apiSecret: 'YOUR_SECRET',
    ios: IOSOptions(
      roktPaymentExtension: RoktPaymentExtensionOptions(
        applePayMerchantId: 'merchant.com.example.app',
      ),
    ),
  ),
);
```

### Custom Events

To log events, import mParticle `EventTypes` and `MPEvent` to write proper event logging calls:

```dart
import 'package:mparticle_flutter_sdk/events/event_type.dart';
import 'package:mparticle_flutter_sdk/events/mp_event.dart';

MPEvent event = MPEvent(
    eventName: 'Test event logged',
    eventType: EventType.Navigation)
  ..customAttributes = { 'key1': 'value1' }
  ..customFlags = { 'flag1': 'value1' };
mpInstance?.logEvent(event);
```

If you have a high-volume event that you would like to forward to client side kits but exclude from uploading to mParticle, set a boolean flag per event.

```dart
import 'package:mparticle_flutter_sdk/events/event_type.dart';
import 'package:mparticle_flutter_sdk/events/mp_event.dart';

MPEvent event = MPEvent(
    eventName: 'Test event logged',
    eventType: EventType.Navigation)
    ..customAttributes = {'key1': 'value1'}
    ..customFlags = {'flag1': 'flagValue1'}
    ..shouldUploadEvent = false;
mpInstance?.logEvent(event);
```

By default, all events upload to the mParticle server unless explicitly set not to. This is also available on Commerce Events when calling `logCommerceEvent`. Support for `logScreenEvent` will be coming in the future.

To log screen events, import mParticle `ScreenEvent`:

```dart
import 'package:mparticle_flutter_sdk/events/screen_event.dart';

ScreenEvent screenEvent =
    ScreenEvent(eventName: 'Screen event logged')
    ..customAttributes = {'key1': 'value1'}
    ..customFlags = {'flag1': 'flagValue1'};
mpInstance?.logScreenEvent(screenEvent);
```

### Commerce Events

To log product commerce events, import `CommerceEvent`, `Product` and `ProductActionType` (optionally `TransactionAttributes`)

```dart
import 'package:mparticle_flutter_sdk/events/commerce_event.dart';
import 'package:mparticle_flutter_sdk/events/product.dart';
import 'package:mparticle_flutter_sdk/events/product_action_type.dart';
import 'package:mparticle_flutter_sdk/events/transaction_attributes.dart';

final Product product1 = Product(name: 'Orange', sku: '123abc', price: 2.4);
final Product product2 = Product(
    name: 'Apple',
    sku: '456abc',
    price: 4.1,
    quantity: 2,
    variant: 'variant',
    category: 'category',
    brand: 'brand',
    position: 1,
    couponCode: 'couponCode',
    attributes: {'key1': 'value1'});
final TransactionAttributes transactionAttributes =
    TransactionAttributes(
        transactionId: '123456',
        affiliation: 'affiliation',
        couponCode: '12412342',
        shipping: 1.34,
        tax: 43.23,
        revenue: 242.23);
CommerceEvent commerceEvent = CommerceEvent.withProduct(
    productActionType: ProductActionType.Purchase,
    product: product1)
..products.add(product2)
..transactionAttributes = transactionAttributes
..currency = 'US'
..screenName = 'One Click Purchase'
..customAttributes = {"foo": "bar", "fuzz": "baz"}
..customFlags = {
    "flag1": "val1",
    "flag2": ["val2", "val3"]
};
mpInstance?.logCommerceEvent(commerceEvent);
```

To log promotion commerce events, import `CommerceEvent`, `Promotion` and `PromotionActionType`:

```dart
import 'package:mparticle_flutter_sdk/events/commerce_event.dart';
import 'package:mparticle_flutter_sdk/events/promotion.dart';
import 'package:mparticle_flutter_sdk/events/promotion_action_type.dart';

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
    promotionActionType: PromotionActionType.View,
    promotion: promotion1)
..promotions.add(promotion2)
..currency = 'US'
..screenName = 'PromotionScreen'
..customAttributes = {"foo": "bar", "fuzz": "baz"}
..customFlags = {
    "flag1": "val1",
    "flag2": ["val2", "val3"]
};
mpInstance?.logCommerceEvent(commerceEvent);
```

To log impression commerce events, import `CommerceEvent`, `Impression` and `Product`

```dart
import 'package:mparticle_flutter_sdk/events/commerce_event.dart';
import 'package:mparticle_flutter_sdk/events/impression.dart';
import 'package:mparticle_flutter_sdk/events/product.dart';

final Product product1 = Product(
    name: 'Orange', sku: '123abc', price: 2.4, quantity: 1);
final Product product2 = Product(
    name: 'Apple',
    sku: '456abc',
    price: 4.1,
    quantity: 2,
    variant: 'variant',
    category: 'category',
    brand: 'brand',
    position: 1,
    couponCode: 'couponCode',
    attributes: {'key1': 'value1'});
final Impression impression1 = Impression(
    impressionListName: 'produce',
    products: [product1, product2]);
final Impression impression2 = Impression(
    impressionListName: 'citrus', products: [product1]);
CommerceEvent commerceEvent =
    CommerceEvent.withImpression(impression: impression1)
    ..impressions.add(impression2)
    ..currency = 'US'
    ..screenName = 'ImpressionScreen'
    ..customAttributes = {"foo": "bar", "fuzz": "baz"}
    ..customFlags = {
        "flag1": "val1",
        "flag2": ["val2", "val3"]
    };
mpInstance?.logCommerceEvent(commerceEvent);
```

### User

Get the current user in order to apply and remove attributes, tags, etc.

```dart
var user = await mpInstance?.getCurrentUser();
```

User Attributes:

```dart
user?.setUserAttribute(key: 'points', value: '1');
```

```dart
user?.setUserAttributeArray(
    key: 'arrayOfStrings', value: ['a', 'b', 'c']);
```

```dart
user?.setUserTag(tag: 'tag1');
```

```dart
user?.getUserAttributes();
```

```dart
user?.removeUserAttribute(key: 'points');
```

```dart
user?.getUserIdentities().then((identities) {
    print(identities); // Map<IdentityType, String>
});
```

### IDSync

IDSync is mParticle’s identity framework, enabling our customers to create a unified view of the customer. To read more about IDSync, see [here](https://docs.mparticle.com/guides/idsync/introduction).

IDSync calls accept an optional `Identity Request`. If no request is provided, an empty identity request is used, which mirrors the behavior of the native iOS and Android SDKs.

#### IdentityRequest

```dart
import 'package:mparticle_flutter_sdk/identity/identity_type.dart';

var identityRequest = MparticleFlutterSdk.identityRequest;
identityRequest
    .setIdentity(
        identityType: IdentityType.CustomerId,
        value: 'customerid')
    .setIdentity(
        identityType: IdentityType.Email,
        value: 'email@gmail.com');
```

After an IdentityRequest is passed to one of the following IDSync methods - `identify`, `login`, `logout`, or `modify`.

Import the `SuccessResponse` and `FailureResponse` classes to write proper callbacks for Identity methods. For brevity, we included an example of full error handling in only the `identify` example below, but this error handling can be used for any of the Identity calls.

#### Identify

You can call `identify` without any parameters to identify with the current user's identities:

```dart
mpInstance?.identity
    .identify()
    .then(
        (IdentityApiResult successResponse) =>
            print("Success Response: $successResponse"),
        onError: (error) {
            var failureResponse = error as IdentityAPIErrorResponse;
            print("Failure Response: $failureResponse");
        }
    );
```

Or with an identity request. The following is a full example with error and success handling. You can adapt the following example with `login`, `modify`, and `logout`.

```dart
import 'package:mparticle_flutter_sdk/identity/identity_api_result.dart';
import 'package:mparticle_flutter_sdk/identity/identity_api_error_response.dart';

var identityRequest = MparticleFlutterSdk.identityRequest;

mpInstance?.identity
    .identify(identityRequest: identityRequest)
    .then(
        (IdentityApiResult successResponse) =>
            print("Success Response: $successResponse"),
        onError: (error) {
            var failureResponse = error as IdentityAPIErrorResponse;
            print("Failure Response: $failureResponse");

            // It is possible for either a client error or a server error to occur during identity calls.
            // First check for the client side error, then you can check the http code for the server error.
            // More details can be found in the platform specific IDSync error handling:
                // iOS - https://docs.mparticle.com/developers/sdk/ios/idsync/#error-handling
                // Web - https://docs.mparticle.com/developers/sdk/web/idsync/#error-handling
                // Android - https://docs.mparticle.com/developers/sdk/android/idsync/#idsync-status-codes
            if (failureResponse.clientErrorCode != null) {
                switch (failureResponse.clientErrorCode) {
                case IdentityClientErrorCodes.RequestInProgress:
                    // there is an Identity request in progress, wait for it to complete before attempting another
                case IdentityClientErrorCodes.ClientSideTimeout:
                case IdentityClientErrorCodes.ClientNoConnection:
                    // retry the IDSync request
                case IdentityClientErrorCodes.SSLError:
                    // SSL configuration issue.
                case IdentityClientErrorCodes.OptOut:
                    // The user has opted out of data collection
                case IdentityClientErrorCodes.Unknown:
                    //
                case IdentityClientErrorCodes.ActiveSession:
                case IdentityClientErrorCodes.ValidationIssue:
                    // A web error that should never arise due to Dart's stronger typing
                case IdentityClientErrorCodes.NativeIdentityRequest:
                default:
                    print(failureResponse.clientErrorCode);
                }
            }
            int? httpCode = failureResponse.httpCode;
            if (httpCode != null && httpCode >= 400) {
                switch (httpCode) {
                case 400:
                case 401:
                case 429:
                case 529:
                default:
                    failureResponse.errors.forEach(
                        (error) => print('${error.code}\n${error.message}'));
                }
            }
        }
    );
```

#### Login

You can call `login` without any parameters:

```dart
mpInstance?.identity
    .login()
    .then(
        (IdentityApiResult successResponse) =>
            print("Success Response: $successResponse"),
        onError: (error) {
            var failureResponse = error as IdentityAPIErrorResponse;
            print("Failure Response: $failureResponse");
        }
    );
```

Or with an identity request:

```dart
var identityRequest = MparticleFlutterSdk.identityRequest;
identityRequest
    .setIdentity(
        identityType: IdentityType.CustomerId,
        value: 'customerid2')
    .setIdentity(
        identityType: IdentityType.Email,
        value: 'email2@gmail.com');

mpInstance?.identity.login(identityRequest: identityRequest).then(
    (IdentityApiResult successResponse) =>
        print("Success Response: $successResponse"),
    onError: (error) {
        var failureResponse = error as IdentityAPIErrorResponse;
        print("Failure Response: $failureResponse");
    });
```

#### Modify

Partial example - you can adapt the `identify` example above with `login`, `modify`, and `logout`.

```dart
var identityRequest = MparticleFlutterSdk.identityRequest;
identityRequest
    .setIdentity(
        identityType: IdentityType.CustomerId,
        value: 'customerid3')
    .setIdentity(
        identityType: IdentityType.Email,
        value: 'email3@gmail.com');

mpInstance?.identity
    .modify(identityRequest: identityRequest)
    .then(
        (IdentityApiResult successResponse) =>
            print("Success Response: $successResponse"),
        onError: (error) {
            var failureResponse = error as IdentityAPIErrorResponse;
            print("Failure Response: $failureResponse");
        }
    );
```

#### Logout

You can call `logout` without any parameters, which is the most common usage:

```dart
mpInstance?.identity
    .logout()
    .then(
        (IdentityApiResult successResponse) =>
            print("Success Response: $successResponse"),
        onError: (error) {
            var failureResponse = error as IdentityAPIErrorResponse;
            print("Failure Response: $failureResponse");
        }
    );
```

Or with an identity request if needed:

```dart
var identityRequest = MparticleFlutterSdk.identityRequest;
identityRequest
    .setIdentity(
        identityType: IdentityType.CustomerId,
        value: 'customerid');

mpInstance?.identity
    .logout(identityRequest: identityRequest)
    .then(
        (IdentityApiResult successResponse) =>
            print("Success Response: $successResponse"),
        onError: (error) {
            var failureResponse = error as IdentityAPIErrorResponse;
            print("Failure Response: $failureResponse");
        }
    );
```

#### Aliasing Users

This is a feature to transition data from "anonymous" users to "known" users. To learn more about user aliasing, see [here](https://docs.mparticle.com/guides/idsync/aliasing/).

```dart
mpInstance?.identity
    .login(identityRequest: identityRequest)
    .then((IdentityApiResult successResponse) {
    String? previousMPID =
        successResponse.previousUser?.getMPID();
    if (previousMPID != null) {
        var userAliasRequest = AliasRequest(
            sourceMpid: previousMPID,
            destinationMpid: successResponse.user.getMPID());
        mpInstance?.identity
            .aliasUsers(aliasRequest: userAliasRequest);
        }
    }
);
```

### Consent

To learn more about Consent on mParticle, see [here](https://docs.mparticle.com/guides/consent-management/);

#### GDPR

GDPR Consent requires a user to add it do:

```dart
var user = await mpInstance?.getCurrentUser();
```

To set a GDPR Consent State:

```dart
Consent gdprConsent = Consent(
    consented: false,
    document: 'document test',
    hardwareId: 'hardwareID',
    location: 'loction test',
    timestamp: DateTime.now().millisecondsSinceEpoch);

user?.addGDPRConsentState(consent: gdprConsent, purpose: 'test');
```

To get a GDPR Consent State:

```dart
Map<String, Consent>? gdprConsent = await user?.getGDPRConsentState(); // String is the purpose set above
```

#### CCPA

To set a CCPA Consent State:

```dart
Consent ccpaConsent = Consent(
    consented: false,
    document: 'document test',
    hardwareId: 'hardwareID',
    location: 'loction test',
    timestamp: DateTime.now().millisecondsSinceEpoch);
user?.addCCPAConsentState(consent: ccpaConsent);
```

To get a CCPA Consent State:

```dart
Consent? ccpaConsent = await user?.getCCPAConsentState();
```

### Native-only Methods

A few methods are currently supported only on iOS/Android SDKs:

- Get the SDK's opt out status

  ```dart
  var isOptedOut = await mpInstance?.getOptOut;
  mpInstance?.setOptOut(optOutBoolean: !isOptedOut!);
  ```

- Check if a kit is active

  ```dart
  import 'package:mparticle_flutter_sdk/kits/kits.dart';

  mpInstance?.isKitActive(kit: Kits['Braze']!).then((isActive) {
      print(isActive);
  });
  ```

- Push Registration

  The method `mpInstance.logPushRegistration()` accepts two parameters. For Android, provide both `pushToken` and `senderId`. For iOS, provide the push token in the first parameter, and simply pass `null` for the second parameter

  #### Android

  ```dart
  mpInstance?.logPushRegistration(pushToken: 'pushToken123', senderId: 'senderId123');
  ```

  #### iOS

  ```dart
  mpInstance?.logPushRegistration(pushToken: 'pushToken123', senderId: null);
  ```

- Set App Tracking Transparency (ATT) Status

  For iOS, you can set a user's ATT status as follows:
  import 'package:mparticle_flutter_sdk/apple/authorization_status.dart';

  ```dart

  mpInstance?.setATTStatus(
        attStatus: MPATTAuthorizationStatus.Authorized,
        timestampInMillis: DateTime.now().millisecondsSinceEpoch);
  ```

# License

Apache 2.0
