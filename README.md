# Apple Container Desktop

macOS GUI for Apple's [container](https://github.com/apple/container) CLI.

Manage containers, machines, compose imports, logs, and integrated terminals from a native desktop app.

## Requirements

- macOS 26.4 or later
- [Apple container CLI](https://github.com/apple/container) installed

## Install

1. Open [GitHub Releases](../../releases/latest).
2. Download `Apple-Container-Desktop-<version>-macos-arm64.zip`.
3. Unzip and move `Apple Container Desktop.app` to `/Applications`.

If macOS blocks the app on first launch, use **Control-click → Open**, or run:

```bash
xattr -cr "/Applications/Apple Container Desktop.app"
```

## Build locally

```bash
xcodebuild -scheme apple.containers.gui \
  -project apple.containers.gui.xcodeproj \
  -configuration Release \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  DEVELOPMENT_TEAM="" \
  build
```

The built app is under `DerivedData` or:

```bash
find ~/Library/Developer/Xcode/DerivedData -path '*Release/apple.containers.gui.app' -maxdepth 6
```

## CI and releases

Releases are built only when you push a version tag. The tag name becomes the app version (`v1.0.1` → app version `1.0.1`).

```bash
git tag v1.0.1
git push origin v1.0.1
```

Pushing to `main` alone does not trigger a build.

## Optional notarized builds

To produce Developer ID signed and notarized builds in GitHub Actions, configure these repository secrets:

| Secret | Description |
| --- | --- |
| `APPLE_CERTIFICATE_BASE64` | Base64-encoded `.p12` Developer ID Application certificate |
| `APPLE_CERTIFICATE_PASSWORD` | Certificate export password |
| `KEYCHAIN_PASSWORD` | Temporary keychain password used during CI |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `APPLE_ID` | Apple ID email for notarization |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password for notarization |

Without these secrets, releases are ad-hoc signed and installable after the Gatekeeper step above. **You do not need an Apple Developer account** for CI or ad-hoc releases.

## License

See the repository license file.

