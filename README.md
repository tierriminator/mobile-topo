# mobile_topo

A Flutter re-implementation of [PocketTopo](https://paperless.bheeb.ch/) — cave
surveying software for modern mobile devices.

## Platform support

DistoX connectivity is **not uniform across platforms**, and this is a hardware
constraint rather than something the app can work around.

| Platform | UI, sketching, import/export | DistoX connection |
|----------|------------------------------|-------------------|
| Android  | ✅                            | ✅ Classic Bluetooth SPP (RFCOMM) |
| macOS    | ✅                            | ✅ IOBluetooth RFCOMM |
| iOS      | ✅                            | ❌ **Not possible** |
| Linux / Windows / Web | ✅ (untested)    | ❌ Not implemented |

### Why the DistoX cannot work on iOS

The DistoX communicates over **Bluetooth Classic** using the Serial Port
Profile (SPP / RFCOMM). It is not a Bluetooth Low Energy device, so BLE APIs
cannot talk to it on any platform.

iOS does not expose Bluetooth Classic SPP to third-party apps. Reaching a
classic serial device requires Apple's External Accessory framework, which only
works with hardware enrolled in Apple's MFi licensing program. The DistoX is not
an MFi device, so no amount of app-side work can establish the connection. This
is the same reason [TopoDroid](https://github.com/marcocorvi/topodroid) is
Android-only.

macOS is unaffected because `IOBluetooth` exposes RFCOMM to any app.

**Practical consequence:** use Android (or macOS) for surveying in the cave.
iOS is limited to viewing, sketching, and exporting data captured elsewhere.

## Development setup

Verified on macOS (Apple Silicon). Steps 3 and 4 are per-target — install only
what you intend to build for.

### 1. Toolchain

The Flutter SDK and JDK are pinned with [mise](https://mise.jdx.dev/) in
`mise.toml` at the **repository root** — one level *above* this Flutter package.

```bash
brew install mise
echo 'eval "$(mise activate zsh)"' >> ~/.zshrc   # then restart your shell
mise install                                     # Flutter + JDK, versions pinned
mise run get                                     # flutter pub get
```

Once mise is shell-activated, `flutter`, `dart`, and `java` resolve through its
shims. Do **not** prefix commands with `mise exec` — it is redundant.

`mise.toml` also exports `ANDROID_HOME`, so no shell export is needed for it.

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
because the macOS target contains a native Swift plugin
(`macos/Runner/BluetoothPlugin.swift`). Install Xcode from the App Store, then:

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
| `mise run l10n` | Regenerate localizations from `l10n/*.arb` |
| `mise run build-macos` | Build the macOS desktop app |
| `mise run build-apk` | Build the Android APK |
| `mise run build-ios` | Build for iOS device (unsigned) |
| `mise run doctor` | `flutter doctor -v` |

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
(`lib/services/bluetooth_adapter.dart`), with one implementation per platform
talking to a native RFCOMM plugin over a shared platform-channel contract
(`mobile_topo/bluetooth`). `main.dart` selects the implementation at startup.
