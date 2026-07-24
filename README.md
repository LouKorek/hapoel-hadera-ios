# Hapoel Hadera FC — iOS App (WKWebView wrapper)

Wraps https://hapoelhadera.co.il in a native iOS shell (based on the PWABuilder iOS template, Firebase removed).

## CI
GitHub Actions (`.github/workflows/ios-release.yml`) builds and uploads to App Store Connect on every push to `main`.

Required repository secrets:
- `ASC_KEY_ID` — App Store Connect API key ID
- `ASC_ISSUER_ID` — App Store Connect API issuer ID
- `ASC_KEY_P8` — full contents of the downloaded `.p8` key file
