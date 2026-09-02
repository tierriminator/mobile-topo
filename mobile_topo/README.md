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

## Getting started

The toolchain is pinned with [mise](https://mise.jdx.dev/) in `mise.toml` at the
repository root — note that this is one level *above* this Flutter package.

```bash
mise install      # Flutter + JDK, versions pinned in mise.toml
mise run get      # flutter pub get
```

All tasks run from the correct directory automatically:

```bash
mise run analyze       # flutter analyze
mise run test          # flutter test
mise run run           # flutter run
mise run build-macos   # build the macOS desktop app
mise run doctor        # flutter doctor -v
```

## Architecture

MVC, with `provider` for dependency injection. See `AGENTS.md` at the repository
root for a full breakdown of models, controllers, services, and the data layer.

Bluetooth is abstracted behind `BluetoothAdapter`
(`lib/services/bluetooth_adapter.dart`), with one implementation per platform
talking to a native RFCOMM plugin over a shared platform-channel contract
(`mobile_topo/bluetooth`). `main.dart` selects the implementation at startup.
