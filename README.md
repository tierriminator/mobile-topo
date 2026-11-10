# mobile_topo

A Flutter re-implementation of [PocketTopo](https://paperless.bheeb.ch/) — cave
surveying software for modern mobile devices.

## Platform support

DistoX connectivity is **not uniform across platforms**, and this is a hardware
constraint rather than something the app can work around. There are two kinds
of DistoX: the **DistoX2** speaks Bluetooth Classic, the **DistoX BLE**
Bluetooth Low Energy (protocol in `docs/distox6/`).

| Platform | UI, sketching, import/export | DistoX2 (Classic SPP) | DistoX BLE |
|----------|------------------------------|-----------------------|------------|
| Android  | ✅                            | ✅ RFCOMM socket       | ✅ GATT |
| macOS    | ✅                            | ✅ IOBluetooth RFCOMM  | ✅ CoreBluetooth |
| iOS      | ✅                            | ❌ **Not possible**    | ✅ CoreBluetooth |
| Linux / Windows / Web | ✅ (untested)    | ❌ Not implemented     | ❌ Not implemented |

### Why the DistoX2 cannot work on iOS

The DistoX2 communicates over **Bluetooth Classic** using the Serial Port
Profile (SPP / RFCOMM). It is not a Bluetooth Low Energy device, so BLE APIs
cannot talk to it on any platform.

iOS does not expose Bluetooth Classic SPP to third-party apps. Reaching a
classic serial device requires Apple's External Accessory framework, which only
works with hardware enrolled in Apple's MFi licensing program. The DistoX2 is
not an MFi device, so no amount of app-side work can establish the connection.
This is the same reason [TopoDroid](https://github.com/marcocorvi/topodroid) is
Android-only.

macOS is unaffected because `IOBluetooth` exposes RFCOMM to any app.

The DistoX BLE needs none of this: CoreBluetooth reaches Bluetooth Low Energy
devices on iOS as on macOS.

**Practical consequence:** with a DistoX2, use Android (or macOS) for surveying
in the cave; on iOS only a DistoX BLE connects.

## Development setup

Verified on macOS (Apple Silicon). Steps 3 and 4 are per-target — install only
what you intend to build for.

### 1. Toolchain

The Flutter SDK and JDK are pinned with [mise](https://mise.jdx.dev/) in
`mise.toml` at the repository root, which is also the Flutter project root.

```bash
brew install mise
echo 'eval "$(mise activate zsh)"' >> ~/.zshrc   # then restart your shell
mise install                                     # Flutter + JDK, versions pinned
mise run get                                     # flutter pub get
```

Once mise is shell-activated, `flutter`, `dart`, and `java` resolve through its
shims. Do **not** prefix commands with `mise exec` — it is redundant.

`mise.toml` also exports `ANDROID_HOME` (unless it is already set), so no shell
export is needed for it.

### 2. Editor

Any editor with Dart/Flutter support. No IDE is required — Android Studio in
particular is **not** needed (see step 3).

### 3. Android target

The headless command-line tools are sufficient; Android Studio only adds an IDE
and the emulator, and the emulator is useless here anyway (it has no Classic
Bluetooth, so the DistoX needs a physical device regardless).

```bash
brew install --cask android-commandlinetools
android sdk install platform-tools
android sdk install "platforms;android-36"
android sdk install "build-tools;36.0.0"
```

Note that `sdkmanager` is deprecated in current SDK releases; `android sdk` is
its replacement. SDK licenses are accepted automatically on the first Gradle
build, or explicitly with `flutter doctor --android-licenses`.

The Android build config tracks Flutter 3.47's template: Gradle 9.3.1,
AGP 9.1.0, KGP 2.4.0, Kotlin DSL (`.kts`).

### 4. Apple targets (macOS / iOS)

**Full Xcode is required** — the Command Line Tools alone are not enough,
because both targets contain a native Swift plugin
(`macos/Runner/BluetoothPlugin.swift`, `ios/Runner/BluetoothPlugin.swift`, and
`darwin/BleCentral.swift`, which both projects compile). Install Xcode from the
App Store, then:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license accept
```

For **iOS** builds you additionally need Xcode's iOS platform component, which
is a multi-gigabyte download separate from Xcode itself:

```bash
xcodebuild -downloadPlatform iOS
```

Without it, iOS builds fail with `Unable to find a destination matching the
provided destination specifier` / `iOS <version> is not installed`. To *run* on
the Simulator rather than just build, also install a runtime via
**Xcode → Settings → Components**.

**CocoaPods is not required and should not be installed.** Both Apple targets
use Swift Package Manager and there are no `Podfile`s in the repository.

### 5. Verify

```bash
mise run doctor
mise run test
```

Two `flutter doctor` warnings are expected and can be ignored:

- `CocoaPods not installed` — correct for this project, see above.
- `Chrome ... not found` — only affects the web target.

## Commands

Every task runs from the correct directory automatically, so they work from
anywhere in the repository.

| Command | Purpose |
|---------|---------|
| `mise run get` | `flutter pub get` |
| `mise run analyze` | Lint |
| `mise run test` | Run tests |
| `mise run run` | Run the app (`-- -d <device_id>` to pick a device) |
| `mise run l10n` | Regenerate localizations from `lib/l10n/*.arb` |
| `mise run build-macos` | Build the macOS desktop app |
| `mise run build-apk` | Build the Android APK |
| `mise run build-apk-release` | Build the signed Android release APK (see [Releasing](#releasing)) |
| `mise run build-ios` | Build for iOS device (unsigned) |
| `mise run doctor` | `flutter doctor -v` |

## Contributing

### Versions

Versions follow [semantic versioning](https://semver.org/).

### Issues

Features and bugs are tracked as
[GitHub issues](https://github.com/tierriminator/mobile-topo/issues).

The maintainer assigns issues to releases with milestones named
`v<version>`, pre-releases included, for example `v1.1.0`, `v1.1.0-beta.1`
or `v1.0.1`. An issue's milestone tells which branch its pull request
targets (see [Branches](#branches)).

The pull request resolving an issue names it with a closing keyword in its
description, for example `Closes #9`, so that merging it closes the issue.
GitHub does this itself for pull requests into `main`;
`.github/workflows/close-issues.yml` does it for pull requests into release
branches.

### Branches

Each minor or major release has its own branch, named
`release/<major>.<minor>`, for example `release/1.1`. Pre-releases and patch
releases have no branch of their own. Other branches can be named freely.

Every change, a feature or a bug fix, gets its own branch and pull request.
Merging the pull request resolves the issue (see [Issues](#issues)).

- **Features and fixes for an upcoming release** target its release branch.
  Its pre-releases (`1.1.0-beta.1`, ...) are published from the release
  branch. The branch is merged into `main` only once it is out of its
  pre-release phase, and the release (`1.1.0`) is then published from
  `main`.
- **Patches** for the current release target `main` directly, never a
  release branch. After the merge, a patch release is published from `main`
  with the patch number increased (`1.0.1`). Open release branches merge
  `main` to take up its patches.

A release branch may always merge the branches of earlier releases, so
`release/1.1` may merge `release/1.0`. Only the oldest release branch may be
merged into `main`.

See [Releasing](#releasing) for how to publish a release.

## Releasing

Android releases are signed APKs published as GitHub releases by
`.github/workflows/release.yml`.

### Release key

Android installs an update only if it is signed with the same key as the
installed app, so every release must use the same key. **Back up the keystore
and its passwords**: without them, existing installs can never be updated.

Generate the key once, outside the repository, in a folder only you can read:

```bash
mkdir -m 700 ~/.keystores
keytool -genkey -v -keystore ~/.keystores/mobile-topo-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

For local release builds, create `android/key.properties` (git-ignored):

```properties
storeFile=/Users/<you>/.keystores/mobile-topo-upload.jks
storePassword=<keystore password>
keyAlias=upload
keyPassword=<key password>
```

Instead of `key.properties`, the build also reads the environment variables
`ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and
`ANDROID_KEY_PASSWORD`.

The workflow sets these from the following repository secrets:

| Secret | Value |
|--------|-------|
| `ANDROID_KEYSTORE_BASE64` | `base64 -i ~/.keystores/mobile-topo-upload.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | Key password |

Release builds without a key fail rather than fall back to the debug key.

### Publishing a release

1. Bump `version` in `pubspec.yaml`. The number after `+` is Android's
   `versionCode` and must increase with every release.
2. Commit, then tag with the version before the `+` and push the tag:

   ```bash
   git tag v1.0.1
   git push origin v1.0.1
   ```

The workflow checks that the tag matches `pubspec.yaml`, runs analysis and
tests, builds the APK and attaches it to a new release as
`mobile-topo-<version>.apk`. Versions with a suffix, such as
`1.0.0-alpha.1+1` tagged `v1.0.0-alpha.1`, are published as pre-releases.

The application ID `ch.tierry.mobiletopo` must never change: Android would
treat the app as a different one and existing installs would not get updates.

## Maintenance notes

**Keep `environment.sdk` in `pubspec.yaml` close to the pinned Flutter version.**
A stale lower bound makes `pub` resolve plugin versions old enough to still use
Flutter's removed v1 Android embedding. That surfaces as a confusing native
compile error (`cannot find symbol: class Registrar`) that looks like a Gradle
problem but is really dependency resolution.

**Do not apply `org.jetbrains.kotlin.android` in `android/app/build.gradle.kts`.**
The Flutter Gradle Plugin applies Kotlin itself; applying it explicitly triggers
a deprecation warning about future build failures.

## Architecture

MVC, with `provider` for dependency injection. See `AGENTS.md` at the repository
root for a full breakdown of models, controllers, services, and the data layer.

Bluetooth is abstracted behind `BluetoothAdapter`
(`lib/services/bluetooth_adapter.dart`), implemented by
`PlatformBluetoothAdapter`, which talks to each platform's native Bluetooth
plugin (RFCOMM and BLE) over a shared platform-channel contract
(`mobile_topo/bluetooth`). The DistoX BLE wraps the DistoX2 protocol;
`lib/services/distox_framing.dart` unwraps it, so everything above speaks
DistoX2 packets.
