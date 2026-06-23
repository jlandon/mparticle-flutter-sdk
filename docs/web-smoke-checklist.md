# Manual Web Smoke Checklist

Required pre-release gate until automated browser E2E exists. Run under **both**:

- `flutter run -d chrome` (JS fallback)
- `flutter run -d chrome --wasm`

From the `example/` directory after replacing `INSERT-API-KEY-HERE` in `web/index.html`.

## Prerequisites

- [ ] Valid mParticle workspace API key in snippet
- [ ] Expected CDN: `https://jssdkcdns.mparticle.com/...`
- [ ] DevTools open (Network + Console)

## Checklist

| #   | Step                                                             | JS  | Wasm | Notes                                |
| --- | ---------------------------------------------------------------- | --- | ---- | ------------------------------------ |
| 1   | `waitUntilReady()` succeeds                                      | ☐   | ☐    |                                      |
| 2   | `isInitialized` expected value                                   | ☐   | ☐    |                                      |
| 3   | Identity identify/login success                                  | ☐   | ☐    | Verify JSON in DevTools              |
| 4   | Identity 400 error path                                          | ☐   | ☐    |                                      |
| 5   | Rapid identify→login (no shared callback state)                  | ☐   | ☐    |                                      |
| 6   | `getUserIdentities` round-trip                                   | ☐   | ☐    |                                      |
| 7   | `modify` omits `previous_mpid`                                   | ☐   | ☐    |                                      |
| 8   | User attribute mutations                                         | ☐   | ☐    |                                      |
| 9   | Analytics: logEvent, logScreenEvent, logError, setOptOut, upload | ☐   | ☐    |                                      |
| 10  | Commerce product/promotion/impression                            | ☐   | ☐    | Include null optional product fields |
| 11  | GDPR get/add/remove                                              | ☐   | ☐    | camelCase keys                       |
| 12  | CCPA get/add/remove                                              | ☐   | ☐    |                                      |
| 13  | `aliasUsers` full + partial-time no-op                           | ☐   | ☐    |                                      |
| 14  | `roktSelectPlacements` (if configured)                           | ☐   | ☐    |                                      |
| 15  | Missing snippet → `MP_WEB_*` PlatformException                   | ☐   | ☐    |                                      |
| 16  | `window.mParticle` + CDN request in Network tab                  | ☐   | ☐    |                                      |
| 17  | Record `main.dart.wasm` + `main.dart.js` sizes                   | ☐   | ☐    | Baseline: **_ / _**                  |

## Sign-off

| Field             | Value       |
| ----------------- | ----------- |
| Tester            |             |
| Date              |             |
| Flutter version   |             |
| Browser / version |             |
| Result            | PASS / FAIL |
