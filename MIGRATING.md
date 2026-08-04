<!-- markdownlint-disable MD024 -->

# Migration Guides

This document describes upgrade steps for breaking changes in the mParticle Flutter SDK. It only covers changes that require action on the Flutter side (`ios/Podfile`, Xcode project settings, Dart code, or the `MPRoktEvents` event channel).

For changes in the underlying native iOS SDK (database migration, deprecated `UIApplicationDelegate` methods, removed `AppDelegateProxy`, regional routing / ATS, Rokt event class renames at the Swift/Objective-C level, etc.), refer to the [mParticle Apple SDK 9 migration guide](https://github.com/mParticle/mparticle-apple-sdk/blob/main/MIGRATING.md#migrating-from-versions--900).

## Migrating from versions < 3.0.0

Version 3.0.0 introduces Dart-only mobile initialization and Swift Package Manager support.

> **Upgrading from 1.x:** Complete [Migrating from versions < 2.0.0](#migrating-from-versions--200) first (iOS 15.6+, CocoaPods subspec updates, and `pod install`).

> **Beta consumers:** iOS fixes listed under [CHANGELOG](./CHANGELOG.md#unreleased) `[Unreleased]` (log-level mapping, `MParticle.initialized` detection, Rokt payment extension init failure) apply when upgrading off `3.0.0-beta.1`; no Dart API break for SPM layout — run `flutter clean`, rebuild iOS, and `pod install` / deintegrate if using CocoaPods.

### Remove native mobile initialization

1. Delete custom `Application` class / `MParticle.start()` from Android.
2. Delete `MParticle.start(with:)` from iOS `AppDelegate`.
3. Remove duplicate mParticle Gradle and Podfile dependencies from your app. **CocoaPods apps:** run `cd ios && pod install` (or `pod deintegrate && pod install` after Podfile changes) so native linkage matches the plugin.

**Partial migration is unsupported.** If native `MParticle.start()` remains, Dart `initialize()` returns `MP_INIT_ALREADY_STARTED` (Android when `MParticle.getInstance()` is non-null; iOS when `MParticle.initialized` is `true`). Remove all native start paths before calling Dart init.

**Flutter hot restart:** Dart/plugin static state resets while the native SDK often stays initialized. Re-calling `initialize()` with the **same** credentials may succeed idempotently when native state matches; expect `MP_INIT_ALREADY_STARTED` when legacy native start remains, credentials differ, or native state diverges. Prefer a full app restart when debugging init or after credential changes.

### Add Dart initialization

```dart
import 'package:flutter/widgets.dart';
import 'package:mparticle_flutter_sdk/mparticle_flutter_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MparticleFlutterSdk.initialize(
    MparticleOptions(
      apiKey: const String.fromEnvironment('MP_API_KEY'),
      apiSecret: const String.fromEnvironment('MP_API_SECRET'),
    ),
  );
}
```

**Web-only upgraders:** follow [Web → Wasm (3.0+)](#web--wasm-30) (bootstrap, HTTPS snippet, JS + Wasm builds, Chrome smoke checklist) before production — do not treat `waitUntilReady()` alone as sufficient for 3.0 web migration.

**Greenfield web apps:** keep the JS snippet in `index.html` and call `await MparticleFlutterSdk.waitUntilReady()`.

### Android Rokt events

Extend `FlutterFragmentActivity` for `MainActivity` when using Rokt event subscriptions (do this before calling `rokt.events()`):

```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

If `MainActivity` is a plain `FlutterActivity`, `rokt.events()` throws `PlatformException` with code `MP_ROKT_LIFECYCLE_UNAVAILABLE`. If no `Activity` is attached when subscribing, the code is `MP_ROKT_ACTIVITY_UNAVAILABLE`.

### Web → Wasm (3.0+) — web-only path

The web implementation migrated from `dart:js` to `dart:js_interop` for [Flutter Wasm](https://docs.flutter.dev/platform-integration/web/wasm) compatibility.

1. Regenerate or update `web/index.html` to the Flutter 3.44+ bootstrap (`flutter_bootstrap.js`).
2. Re-merge your mParticle snippet in `<head>` (HTTPS CDN only).
3. Verify builds:

```bash
cd example   # or your app
flutter build web
flutter build web --wasm
```

Green builds alone do not validate runtime. Before step 4, run the example under Chrome for JS and Wasm (`flutter run -d chrome` and `flutter run -d chrome --wasm` from `example/`, as in the smoke checklist).

4. Run the [manual smoke checklist](./docs/web-smoke-checklist.md) under JS and Wasm.

**Additive behavior:** identity JS callbacks time out after 60 seconds with a structured `-1` client error JSON envelope.

See [docs/web-architecture.md](./docs/web-architecture.md) for wire contracts and `MP_WEB_*` error codes.

2.x native init could fail silently when using deprecated `getInstance()` (returns `null`). 3.0 `initialize()` throws typed exceptions:

```dart
try {
  await MparticleFlutterSdk.initialize(options);
} on MparticleAlreadyInitializedException catch (e) {
  // Second call, legacy native init, or hot restart — e.message has native detail
} on MparticleInitException catch (e) {
  // e.code is a stable MP_INIT_* string; e.message includes native detail when available
}
```

| Code                           | Android native | iOS native | Dart-only                                                                            |
| ------------------------------ | -------------- | ---------- | ------------------------------------------------------------------------------------ |
| `MP_INIT_INVALID_CREDENTIALS`  | yes            | yes        | yes (validate)                                                                       |
| `MP_INIT_INVALID_BASE_URL`     | yes            | yes        | yes (validate)                                                                       |
| `MP_INIT_INVALID_OPTIONS`      | yes            | yes        | yes (validate)                                                                       |
| `MP_INIT_ALREADY_STARTED`      | yes            | yes        | yes                                                                                  |
| `MP_INIT_TIMEOUT`              | —              | —          | yes (`initialize()` watchdog; web `waitUntilReady()` uses the same code on deadline) |
| `MP_INIT_UNSUPPORTED_PLATFORM` | —              | —          | yes (web)                                                                            |

After `MP_INIT_TIMEOUT` on mobile, native initialization may still complete under the hood. Call `initialize()` again with the same credentials when logcat/Xcode suggests the SDK started; `MparticleFlutterSdk.instance` stays unavailable until a successful Dart init completes.

### Map native options to MparticleOptions

| 2.x native setting                   | 3.0 Dart field                                                                                                       |
| ------------------------------------ | -------------------------------------------------------------------------------------------------------------------- |
| API key / secret                     | `apiKey`, `apiSecret`                                                                                                |
| Log level                            | `logLevel` (`MparticleLogLevel`) — on iOS, `info` and `debug` both map to native Debug (Apple SDK has no INFO level) |
| Environment                          | `environment` (`MparticleEnvironment`)                                                                               |
| CNAME / custom base URL              | `customBaseUrl` (HTTPS)                                                                                              |
| Startup identify request             | `bootstrapIdentityRequest` (max 10 identities, 256 chars each)                                                       |
| Rokt payment extension (AppDelegate) | `ios.roktPaymentExtension`                                                                                           |
| Init watchdog                        | `initTimeout` (Dart-only, default 5s, clamped 1–30s)                                                                 |

### Replace `getInstance()`

| Before                                    | After                                                |
| ----------------------------------------- | ---------------------------------------------------- |
| `await MparticleFlutterSdk.getInstance()` | `await MparticleFlutterSdk.initialize(options)`      |
| nullable `mpInstance?.logEvent()`         | `MparticleFlutterSdk.instance.logEvent()` after init |

`getInstance()` remains as a deprecated compatibility helper for legacy native-init apps but is not recommended. It returns `null` on failure instead of throwing typed errors.

### Platform `isInitialized` behavior

| Platform | Pre-3.0                          | 3.0+ channel behavior                             |
| -------- | -------------------------------- | ------------------------------------------------- |
| iOS      | always `true` (1.1.1 regression) | `true` when `MParticle.initialized` is `true`     |
| Android  | reflects native SDK              | `true` when `MParticle.getInstance()` is non-null |
| Web      | JS store flag                    | `true` when web snippet reports ready             |

After removing native init, use Dart `initialize()` on mobile — do not rely on `isInitialized` polling during migration.

### iOS `isInitialized` behavior (summary)

Returns `true` when the native Apple SDK reports initialized (`MParticle.initialized`), aligned with Android `getInstance()` semantics. Legacy native-init apps without Dart `initialize()` will see `true` once the SDK has started.

### Flutter version requirement

Requires **Flutter ≥ 3.44.0** — `pubspec.yaml` enforces this floor for 3.0.x. Swift Package Manager is the default iOS integration path in Flutter 3.44+.

For SPM, all plugin native code ships inside `ios/mparticle_flutter_sdk/` in the published package, including `InitializeOptionsParserPackage` (local path dependency under the same tree). CocoaPods compiles the parser sources via the podspec. The nested package is also used for **unit tests only** and is not a separate app dependency beyond the plugin’s `Package.swift`.

The plugin `Package.swift` references a local `FlutterFramework` package that Flutter symlinks next to the plugin when an app resolves SPM dependencies (under the app’s `ios/Flutter/ephemeral/Packages/.packages/` tree, not as `<repo>/ios/FlutterFramework`). App builds and CI obtain it via `flutter build ios --config-only` from an app that depends on this plugin — see [build-ios.yml](./.github/workflows/build-ios.yml). **Note:** GitHub Actions in this repo pin Xcode **16.4** for reproducible CI; this branch’s SPM layout targets **Xcode 26 / Swift 6.3** compatibility on your machine — use a matching Xcode locally when validating Swift 6.3-only behavior. **`InitializeOptionsParser` unit tests** do not need `FlutterFramework`:

```bash
cd ios/mparticle_flutter_sdk/InitializeOptionsParserPackage && swift test
```

### Rokt (3.0+)

- **Breaking:** `Rokt.events(...)` returns `Future<void>` in 3.0 — **await** `events(identifier, ...)` before `selectPlacements` or `selectShoppableAds` for that identifier (2.x fire-and-forget call sites can race subscription registration on Android).
- Rokt event delivery uses explicit subscription by identifier through `Rokt.events(...)`.

For iOS payment-enabled shoppable ads, pass `IOSOptions.roktPaymentExtension` on `MparticleOptions` at `initialize()` (see [README.md — Rokt](./README.md#rokt)). Native AppDelegate registration is no longer required after Dart-only init.

```dart
const identifier = 'shoppable-ads-placement';
final mp = await MparticleFlutterSdk.initialize(
  MparticleOptions(
    apiKey: const String.fromEnvironment('MP_API_KEY'),
    apiSecret: const String.fromEnvironment('MP_API_SECRET'),
    ios: IOSOptions(
      roktPaymentExtension: RoktPaymentExtensionOptions(
        applePayMerchantId: 'merchant.com.example.app',
      ),
    ),
  ),
);
await mp.rokt.events(identifier, (event) {
  // handle Rokt events for this placement
});
await mp.rokt.selectShoppableAds(
  identifier: identifier,
  attributes: {'email': 'user@example.com'},
);
```

- **iOS**: proxies to `MParticle.sharedInstance().rokt.selectShoppableAds(...)`.
- **Android**: the method is exposed for API parity but is a no-op (logs a warning).
- **Web**: not implemented — calls throw `PlatformException` with code `Unimplemented`.

### iOS dependency pins

| Dependency           | CocoaPods         | SPM floor |
| -------------------- | ----------------- | --------- |
| mParticle-Apple-SDK  | `~> 9.2`          | `9.2.0`   |
| mParticle-Rokt       | bundled in plugin | `9.0.0`   |
| RoktPaymentExtension | bundled in plugin | `2.0.0`   |

## Migrating from versions < 2.0.0

Version 2.0.0 wraps the mParticle Apple SDK 9 on iOS. No Dart source changes are required for existing `selectPlacements`, `purchaseFinalized`, or `MPRoktEvents` integrations, but the iOS build configuration must be updated.

### iOS deployment target raised to 15.6

The plugin now requires iOS 15.6+. Update the following in your app:

- `ios/Podfile`:

  ```ruby
  platform :ios, '15.6'
  ```

- `ios/Flutter/AppFrameworkInfo.plist` — set `MinimumOSVersion` to `15.6`.
- In Xcode, raise the Runner target's **iOS Deployment Target** to `15.6`.

After updating, run:

```sh
cd ios
pod deintegrate
pod install
cd ..
```

### Updated CocoaPods dependencies

The plugin now depends on mParticle Apple SDK 9. In SDK 9 the podspec was restructured and subspecs are gone, so the `/mParticle` suffix is no longer valid:

| Before (1.x)                           | After (2.0.0)                |
| -------------------------------------- | ---------------------------- |
| `mParticle-Apple-SDK/mParticle ~> 8.5` | `mParticle-Apple-SDK ~> 9.0` |

If your app's `Podfile` pins a subspec (for example `pod 'mParticle-Apple-SDK/mParticle', ...`), update it to the new form above.

### Rokt event channel — new event types

Consumers of the `EventChannel('MPRoktEvents')` stream will receive four additional `event` values. The string values for **previously existing** event types are unchanged (`FirstPositiveEngagement`, `OfferEngagement`, `PlacementReady`, `PlacementClosed`, `PlacementCompleted`, `PlacementFailure`, `PlacementInteractive`, `PositiveEngagement`, `OpenUrl`, `CartItemInstantPurchase`, `InitComplete`), so existing listeners continue to work.

New event types and their payload keys:

| `event`                            | Additional keys                                  |
| ---------------------------------- | ------------------------------------------------ |
| `CartItemInstantPurchaseInitiated` | `cartItemId`, `catalogItemId`                    |
| `CartItemInstantPurchaseFailure`   | `cartItemId`, `catalogItemId`, `error`           |
| `InstantPurchaseDismissal`         | —                                                |
| `CartItemDevicePay`                | `cartItemId`, `catalogItemId`, `paymentProvider` |

Any `switch (event['event'])` that did not have a `default` branch should be extended to handle (or explicitly ignore) the new types. Example:

```dart
roktEventChannel.receiveBroadcastStream().listen((dynamic event) {
  final Map<String, dynamic> payload = Map<String, dynamic>.from(event);
  switch (payload['event']) {
    case 'PlacementReady':
      // ...
      break;
    case 'CartItemInstantPurchase':
      // ...
      break;
    case 'CartItemInstantPurchaseInitiated':
    case 'CartItemInstantPurchaseFailure':
    case 'InstantPurchaseDismissal':
    case 'CartItemDevicePay':
      // New in 2.0.0 — handle or ignore as needed.
      break;
    default:
      break;
  }
});
```

2.x added iOS-only `selectShoppableAds` on the native Rokt bridge. In **3.0+**, use Dart `initialize()` with `IOSOptions.roktPaymentExtension` and the [Rokt (3.0+)](#rokt-30) sample — do not register the payment extension from AppDelegate after removing native init.
