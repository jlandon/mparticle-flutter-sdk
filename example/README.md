# Example app

## Mobile

```bash
cd example
flutter run \
  --dart-define=MP_API_KEY=YOUR_KEY \
  --dart-define=MP_API_SECRET=YOUR_SECRET
```

Placeholder credentials (`example-key` / `example-secret`) work for UI smoke tests.

## Web

Web uses the mParticle JS snippet in `web/index.html` — replace `INSERT-API-KEY-HERE` with your workspace key. Web does **not** use `--dart-define=MP_API_SECRET`.

```bash
cd example
flutter run -d chrome
flutter run -d chrome --wasm
flutter build web
flutter build web --wasm
```

Prerequisites and pass/fail criteria: [docs/web-smoke-checklist.md](../docs/web-smoke-checklist.md).

Expected CDN: `https://jssdkcdns.mparticle.com/js/v2/<API_KEY>/mparticle.js`
