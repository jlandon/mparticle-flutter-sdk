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

### Replace `getInstance()`

| Before                                    | After                                                |
| ----------------------------------------- | ---------------------------------------------------- |
| `await MparticleFlutterSdk.getInstance()` | `await MparticleFlutterSdk.initialize(options)`      |
| nullable `mpInstance?.logEvent()`         | `MparticleFlutterSdk.instance.logEvent()` after init |

### iOS `isInitialized` behavior

Pre-init calls now return `false` on iOS (2.x always returned `true`).

### Flutter version requirement

Requires **Flutter ≥ 3.44.0** when using Swift Package Manager (default in Flutter 3.44+). CocoaPods-only apps on older Flutter can disable SPM with `flutter config --no-enable-swift-package-manager`.

### Android Rokt events

Extend `FlutterFragmentActivity` for `MainActivity` when using Rokt event subscriptions.

### iOS dependency pins

| Dependency           | CocoaPods         | SPM floor |
| -------------------- | ----------------- | --------- |
| mParticle-Apple-SDK  | `~> 9.2`          | `9.2.0`   |
| mParticle-Rokt       | bundled in plugin | `9.0.0`   |
| RoktPaymentExtension | bundled in plugin | `2.0.0`   |

### Beta publish runbook

1. Set `pubspec.yaml` version to `3.0.0-beta.1`.
2. Run full CI verification.
3. `flutter pub publish` and tag `v3.0.0-beta.1`.
4. After community validation, cut GA `3.0.0` via release workflow.

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
await MparticleFlutterSdk.getInstance().then((mp) => mp?.rokt.selectShoppableAds(
      identifier: 'shoppable-ads-placement',
      attributes: {'email': 'user@example.com'},
    ));
```

- **iOS**: proxies to `MParticle.sharedInstance().rokt.selectShoppableAds(...)`.
- **Android**: the method is exposed for API parity but is a no-op (logs a warning).
- **Web**: not implemented — calls will throw `MissingPluginException`.

Rokt event delivery now uses explicit subscription by identifier through `Rokt.events(...)`. Call `events(identifier, ...)` before `selectPlacements(...)` or `selectShoppableAds(...)` for that identifier.

The Rokt payment extension (for example `RoktPaymentExtension`) is **not** proxied through Dart. Integrators must add the pod and register it directly from native Swift/Objective-C in the host app (for example `ios/Runner/AppDelegate.swift`), after `MParticle.sharedInstance().start(with:)`.
