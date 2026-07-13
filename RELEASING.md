# GitHub Releases and OTA updates

The app checks this Sparkle feed:

`https://github.com/sb4yd3e/Mac-Notch-AI-Limit-widget/releases/latest/download/appcast.xml`

For each release:

1. Build a Developer ID signed and notarized app with `scripts/package_release.sh <version> <build-number>`.
2. Confirm the universal app launches from `dist/AI Limit Notch.app`.
3. Generate the signed appcast with Sparkle's `generate_appcast` tool.
4. Create a GitHub Release whose tag matches the app version.
5. Upload the versioned zip, checksum, and `appcast.xml` as release assets.

The packaged app's `Info.plist` must include the matching Sparkle public key in `SUPublicEDKey`. Keep the private key outside the repository, preferably in the release CI secret store.

`Open at Login` uses `SMAppService.mainApp` and therefore becomes available only when the executable is running inside an installed `.app` bundle.
