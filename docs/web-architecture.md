# Web Architecture (mParticle Flutter SDK)

Wasm-safe web implementation for the mParticle Flutter plugin. Wire contracts below must stay stable for mobile/shared Dart parsers.

## Module map

| Module                                          | Responsibility                                                      |
| ----------------------------------------------- | ------------------------------------------------------------------- |
| `lib/src/web_helpers/js_runtime.dart`           | Generic interop (`jsStringify`, `jsDartify`, `callMethodVarArgsOn`) |
| `lib/src/web_helpers/mparticle_globals.dart`    | `requireMParticle*`, namespace guards, `MParticleWebContext`        |
| `lib/src/web_helpers/js_bridge.dart`            | Re-exports + `MParticleJsBridge` interface                          |
| `lib/src/web_helpers/web_identity_helpers.dart` | Pure Dart identity/consent mapping                                  |
| `lib/src/web_helpers/identity_web.dart`         | Identity JS orchestration + `invokeIdentityCallback`                |
| `lib/src/web_helpers/consent_web.dart`          | GDPR/CCPA                                                           |
| `lib/src/web_helpers/commerce_web.dart`         | Commerce events                                                     |
| `lib/src/web_helpers/commerce_helpers.dart`     | Pure Dart commerce arg builder                                      |
| `lib/src/web_helpers/user_web.dart`             | User attributes/identities                                          |
| `lib/src/web_helpers/analytics_web.dart`        | Events, opt-out, Rokt                                               |
| `lib/mparticle_flutter_sdk_web.dart`            | Thin MethodChannel router                                           |

Only `js_runtime.dart` and `mparticle_globals.dart` import `dart:js_interop_unsafe`.

## Web error codes (`MP_WEB_*`)

| Code                          | Meaning                       | Remediation                                                    |
| ----------------------------- | ----------------------------- | -------------------------------------------------------------- |
| `MP_WEB_SNIPPET_MISSING`      | `window.mParticle` not found  | Add mParticle snippet to `index.html` before Flutter bootstrap |
| `MP_WEB_NOT_READY`            | SDK not initialized           | Wait for `waitUntilReady()`; verify API key                    |
| `MP_WEB_INTEROP_FAILED`       | Unexpected interop failure    | Check browser console; verify CDN load                         |
| `MP_WEB_IDENTITY_UNAVAILABLE` | `mParticle.Identity` missing  | Verify snippet version / workspace config                      |
| `MP_WEB_CONSENT_UNAVAILABLE`  | `mParticle.Consent` missing   | Same as above                                                  |
| `MP_WEB_COMMERCE_UNAVAILABLE` | `mParticle.eCommerce` missing | Same as above                                                  |
| `MP_WEB_ROKT_UNAVAILABLE`     | `mParticle.Rokt` missing      | Enable Rokt kit in workspace                                   |

## MethodChannel wire contract

| Method                                                                              | Return        | Notes                                 |
| ----------------------------------------------------------------------------------- | ------------- | ------------------------------------- |
| `isInitialized`                                                                     | `bool`        | `MP_WEB_NOT_READY` on failure         |
| `getAppName`                                                                        | `String`      | Passthrough                           |
| `logError`                                                                          | `null`        | Side effect                           |
| `logEvent`                                                                          | `null`        | Optional `shouldUploadEvent`          |
| `logScreenEvent`                                                                    | `null`        | Uses `logPageView`                    |
| `setOptOut`                                                                         | `null`        | Boolean flag                          |
| `upload`                                                                            | `null`        | Force upload                          |
| `getMPID`                                                                           | `String`      | Current user                          |
| `getUserAttributes`                                                                 | `String`      | Raw JSON.stringify                    |
| `getUserIdentities`                                                                 | `String`      | String-key int map via converters     |
| `setUserAttribute` / `removeUserAttribute` / `setUserAttributeArray` / `setUserTag` | `null`        | Mutations                             |
| `identify` / `login` / `logout` / `modify`                                          | JSON `String` | See identity envelope                 |
| `aliasUsers`                                                                        | `null`        | Partial start/end → no-op             |
| `logCommerceEvent`                                                                  | `bool?`       | Product/promotion/impression branches |
| GDPR/CCPA get                                                                       | `String`      | PascalCase → camelCase remapping      |
| GDPR/CCPA add/remove                                                                | `null`        | Side effects                          |
| `roktSelectPlacements`                                                              | `null`        | Rokt side effect                      |
| Unsupported                                                                         | —             | `PlatformException` `Unimplemented`   |

### Identity envelope JSON

- Success (`http_code: 200`): includes `previous_mpid` except for `modify`
- Client codes `-1`..`-5`: `http_code` is `null`; single error with string `code`
- `4xx`: errors from JS `body.errors` array
- `5xx`: raw `body.errors` without normalization
- **Timeout (60s):** returns `-1`-style client error JSON (additive behavior)

Upstream parsers: `lib/src/identity/identity_helpers.dart`, `lib/src/user.dart`.

## Async interop pattern

Use `invokeIdentityCallback` in `identity_web.dart` for any new async JS callbacks:

1. Store `.toJS` reference until Completer completes
2. 60s timeout with structured error JSON
3. Cancel timer on early completion
4. Null callback ref in `finally`
