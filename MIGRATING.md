<!-- markdownlint-disable MD024 -->

# Migration Guides

This document describes upgrade steps for breaking changes in the mParticle Flutter SDK. It only covers changes that require action on the Flutter side (`ios/Podfile`, Xcode project settings, Dart code, or the `MPRoktEvents` event channel).

For changes in the underlying native iOS SDK (database migration, deprecated `UIApplicationDelegate` methods, removed `AppDelegateProxy`, regional routing / ATS, Rokt event class renames at the Swift/Objective-C level, etc.), refer to the [mParticle Apple SDK 9 migration guide](https://github.com/mParticle/mparticle-apple-sdk/blob/main/MIGRATING.md#migrating-from-versions--900).

## Migrating from versions < 3.0.0

Version 3.0.0 introduces Dart-only mobile initialization and Swift Package Manager support.

### Remove native mobile initialization

1. Delete custom `Application` class / `MParticle.start()` from Android.
2. Delete `MParticle.start(with:)` from iOS `AppDelegate`.
3. Remove duplicate mParticle Gradle and Podfile dependencies from your app.

**Partial migration is unsupported.** If native `MParticle.start()` remains, Dart `initialize()` returns `MP_INIT_ALREADY_STARTED` (Android when `MParticle.getInstance()` is non-null; iOS when `MParticle.initialized` is `true`). Remove all native start paths before calling Dart init.

**Flutter hot restart:** The native SDK stays initialized across hot restart, but Dart/plugin static state resets. Re-calling `initialize()` returns `MP_INIT_ALREADY_STARTED` even with the same credentials — perform a full app restart instead.

### Add Dart initialization

```dart
WidgetsFlutterBinding.ensureInitialized();
await MparticleFlutterSdk.initialize(
  MparticleOptions(
    apiKey: const String.fromEnvironment('MP_API_KEY'),
    apiSecret: const String.fromEnvironment('MP_API_SECRET'),
  ),
);
```

Web apps: keep the JS snippet in `index.html` and call `await MparticleFlutterSdk.waitUntilReady()`.

### Web → Wasm (3.0+)

The web implementation migrated from `dart:js` to `dart:js_interop` for [Flutter Wasm](https://docs.flutter.dev/platform-integration/web/wasm) compatibility.

1. Regenerate or update `web/index.html` to the Flutter 3.44+ bootstrap (`flutter_bootstrap.js`).
2. Re-merge your mParticle snippet in `<head>` (HTTPS CDN only).
3. Verify builds:

```bash
cd example   # or your app
flutter build web
flutter build web --wasm
```

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

| Code                           | Android native | iOS native | Dart-only      |
| ------------------------------ | -------------- | ---------- | -------------- |
| `MP_INIT_INVALID_CREDENTIALS`  | yes            | yes        | yes (validate) |
| `MP_INIT_INVALID_BASE_URL`     | yes            | yes        | yes (validate) |
| `MP_INIT_INVALID_OPTIONS`      | yes            | yes        | yes (validate) |
| `MP_INIT_ALREADY_STARTED`      | yes            | yes        | yes            |
| `MP_INIT_TIMEOUT`              | —              | —          | yes            |
| `MP_INIT_UNSUPPORTED_PLATFORM` | —              | —          | yes (web)      |

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

Requires **Flutter ≥ 3.44.0** when using Swift Package Manager (default in Flutter 3.44+). CocoaPods-only apps on older Flutter can disable SPM with `flutter config --no-enable-swift-package-manager`.

### Android Rokt events

Extend `FlutterFragmentActivity` for `MainActivity` when using Rokt event subscriptions:

```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

If `MainActivity` is a plain `FlutterActivity`, `rokt.events()` throws `PlatformException` with code `MP_ROKT_LIFECYCLE_UNAVAILABLE`.

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

### New Rokt API: `selectShoppableAds` (iOS only)

```dart
final mp = await MparticleFlutterSdk.initialize(
  MparticleOptions(
    apiKey: const String.fromEnvironment('MP_API_KEY'),
    apiSecret: const String.fromEnvironment('MP_API_SECRET'),
  ),
);
await mp.rokt.selectShoppableAds(
  identifier: 'shoppable-ads-placement',
  attributes: {'email': 'user@example.com'},
);
```

- **iOS**: proxies to `MParticle.sharedInstance().rokt.selectShoppableAds(...)`.
- **Android**: the method is exposed for API parity but is a no-op (logs a warning).
- **Web**: not implemented — calls throw `PlatformException` with code `Unimplemented`.

Rokt event delivery now uses explicit subscription by identifier through `Rokt.events(...)`. Call `events(identifier, ...)` before `selectPlacements(...)` or `selectShoppableAds(...)` for that identifier.

**3.0+:** Register the Rokt payment extension from Dart via `IOSOptions.roktPaymentExtension` on `MparticleOptions` (see [README.md](./README.md)). Native AppDelegate registration is no longer required after Dart-only init.

**2.x:** The Rokt payment extension was registered from native Swift/Objective-C in the host app (for example `ios/Runner/AppDelegate.swift`), after `MParticle.sharedInstance().start(with:)`.
