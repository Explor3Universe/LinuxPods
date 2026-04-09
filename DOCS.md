# Repository Guidelines

## Architecture Overview

LinuxPods uses a **daemon + plasmoid** architecture (same pattern as KDE Connect):

```
linuxpods-daemon (C++ headless backend)
  ├── AirPods protocol (L2CAP socket + AAP packets)
  ├── BluetoothMonitor (BlueZ D-Bus)
  ├── BleManager (BLE proximity scanning)
  ├── MediaController (MPRIS + PulseAudio)
  ├── DeviceInfo / Battery / EarDetection (state models)
  ├── LinuxPodsService (orchestrator, owns all of the above)
  ├── D-Bus adaptor → me.kavishdevar.linuxpods on session bus
  └── QLocalServer for CLI (librepods-ctl)

plasmoid (QML-only Plasma 6 widget)
  ├── PlasmoidItem in system tray (X-Plasma-NotificationArea)
  ├── CompactRepresentation (tray icon)
  ├── FullRepresentation (popup with controls)
  ├── DbusBackend.qml (D-Bus client via gdbus + P5Support.DataSource)
  └── All UI uses Plasma Components (PlasmaComponents3, Kirigami)
```

Communication: **plasmoid → gdbus call → D-Bus → daemon → AirPods**.

## Project Structure

```
src/
  main.cpp                    # Standalone GUI entry (fallback for non-Plasma)
  service/
    linuxpodsservice.h/.cpp   # Core backend logic (headless, no UI)
  dbus/
    linuxpodsdbusadaptor.h    # D-Bus adaptor (30 properties, 13 methods)
    me.kavishdevar.linuxpods.Manager.xml  # D-Bus interface definition
  daemon/
    main.cpp                  # Headless daemon entry point
  trayiconmanager.*           # KStatusNotifierItem (used by standalone GUI only)
  airpods_packets.h           # AAP protocol packet builders
  deviceinfo.hpp              # Device state model (Q_PROPERTY-based)
  battery.hpp                 # Battery state model
  eardetection.hpp            # Ear detection state
  enums.h                     # NoiseControlMode, AirPodsModel enums
  BluetoothMonitor.*          # BlueZ D-Bus device connect/disconnect
  autostartmanager.hpp        # XDG autostart .desktop management
  systemsleepmonitor.hpp      # logind sleep/wake events
  ble/                        # BLE scanning and proximity advertising
  media/                      # MPRIS + PulseAudio integration
  thirdparty/                 # QR-Code-generator (vendored)
  assets/                     # Icons, fonts, desktop entry
  translations/               # i18n

plasmoid/
  metadata.json               # Plasma 6 widget metadata
  contents/ui/
    main.qml                  # PlasmoidItem entry point
    CompactRepresentation.qml # Tray icon
    FullRepresentation.qml    # Popup UI
    DbusBackend.qml           # D-Bus client (gdbus + DataSource)
    BatteryItem.qml           # Circular battery ring (Shape/ShapePath)
    FeatureRow.qml            # Toggle row

data/
  me.kavishdevar.linuxpods.service  # D-Bus activation file
  linuxpods-daemon.service          # Systemd user service
```

## Build Commands

```bash
# Local build (use space-free path for build dir)
cmake -S src -B ~/.cache/linuxpods-build
cmake --build ~/.cache/linuxpods-build -j$(nproc)

# Run daemon
~/.cache/linuxpods-build/linuxpods-daemon

# Run standalone GUI (fallback)
~/.cache/linuxpods-build/librepods --hide

# CLI
~/.cache/linuxpods-build/librepods-ctl noise:anc

# RPM build
./build.sh              # installs BuildRequires first
./build.sh --skip-deps  # skip dnf builddep

# Install plasmoid locally for testing (no RPM needed)
cp -r plasmoid/* ~/.local/share/plasma/plasmoids/me.kavishdevar.linuxpods/

# Deploy updated QML without rebuild (plasmoid is pure QML)
sudo cp plasmoid/contents/ui/*.qml /usr/share/plasma/plasmoids/me.kavishdevar.linuxpods/contents/ui/
kquitapp6 plasmashell && kstart plasmashell
```

## D-Bus Interface

Service: `me.kavishdevar.linuxpods` on session bus
Object: `/me/kavishdevar/linuxpods`
Interface: `me.kavishdevar.linuxpods.Manager`

### Key Properties (all read-only, use methods to change)
- `Connected` (bool), `DeviceName` (string), `BluetoothAddress` (string)
- `LeftBatteryLevel` (byte), `LeftBatteryCharging` (bool), `LeftBatteryAvailable` (bool)
- `RightBatteryLevel`, `RightBatteryCharging`, `RightBatteryAvailable`
- `CaseBatteryLevel`, `CaseBatteryCharging`, `CaseBatteryAvailable`
- `NoiseControlMode` (int: 0=Off, 1=ANC, 2=Transparency, 3=Adaptive)
- `ConversationalAwareness` (bool), `HearingAidEnabled` (bool), `OneBudANCMode` (bool)
- `EarDetectionBehavior` (int: 0=OneEar, 1=Both, 2=Never)

### Key Methods
- `SetNoiseControlMode(int)`, `SetConversationalAwareness(bool)`
- `SetHearingAidEnabled(bool)`, `SetOneBudANCMode(bool)`
- `SetEarDetectionBehavior(int)`, `SetNotificationsEnabled(bool)`
- `RenameDevice(string)`, `RequestMagicCloudKeys()`

### Testing D-Bus
```bash
# Read all properties
gdbus call --session -d me.kavishdevar.linuxpods \
  -o /me/kavishdevar/linuxpods \
  -m org.freedesktop.DBus.Properties.GetAll \
  me.kavishdevar.linuxpods.Manager

# Call a method (gdbus uses plain values, NOT dbus-send int32: syntax)
gdbus call --session -d me.kavishdevar.linuxpods \
  -o /me/kavishdevar/linuxpods \
  -m me.kavishdevar.linuxpods.Manager.SetNoiseControlMode 2

# Watch daemon logs
journalctl --user -u linuxpods-daemon -f

# Watch plasmoid QML errors
journalctl --user -t plasmashell -f | grep -i linuxpod
```

## Critical Implementation Notes

### Plasmoid gotchas (Plasma 6)

1. **No `preferredRepresentation`** — setting `preferredRepresentation: compactRepresentation` prevents system tray from expanding the popup on click. Leave it unset.

2. **CompactRepresentation scope** — inside CompactRepresentation.qml, `root` does NOT refer to PlasmoidItem. To access backend, use a property alias or access via the PlasmoidItem's id. System tray handles click-to-expand automatically — no MouseArea needed in CompactRepresentation.

3. **gdbus syntax** — `gdbus call` uses plain values (`2`, `true`), NOT `dbus-send` typed syntax (`int32:2`, `boolean:true`). The latter silently fails.

4. **DataSource caching** — `P5Support.DataSource` with `engine: "executable"` caches by source string. Append `#N` (shell comment) with incrementing counter to bust the cache for repeated calls.

5. **`Kirigami.Theme.separatorColor`** — may be undefined in Shape/ShapePath context. Use `Qt.rgba(Kirigami.Theme.textColor.r, ..., 0.15)` instead.

6. **System tray duplicate icons** — if plasmoid appears twice, check `~/.config/plasma-org.kde.plasma.desktop-appletsrc` for duplicate applet entries AND extraItems. A notification area plasmoid should only be in `extraItems`/`knownItems`, not as a separate `[Applets][N]` entry.

### Backend architecture

- `LinuxPodsService` is the single source of truth. It owns all BLE/Bluetooth/media/settings logic.
- `LinuxPodsDBusAdaptor` wraps service properties for D-Bus. Emits `PropertiesChanged` on state changes.
- The daemon does NOT create any GUI (no QApplication, no KStatusNotifierItem, no QML).
- `AirPodsTrayApp` in `src/main.cpp` is the standalone GUI wrapper (fallback for non-Plasma desktops). It creates `LinuxPodsService` + QML engine + `TrayIconManager`.

### AAP Protocol flow
1. Socket connects via L2CAP to UUID `74ec2172-0bad-4d01-8f77-997b2be0722a`
2. Handshake → SET_SPECIFIC_FEATURES → REQUEST_NOTIFICATIONS
3. AirPods respond with METADATA (name, model), battery status, noise control state
4. Commands sent as AAP packets via `writePacketToSocket()`
5. Responses parsed in `parseData()` and stored in `DeviceInfo`

## Coding Style

- C++: 4-space indent, Qt signal/slot patterns, braces on own line
- QML: Plasma Components (`PlasmaComponents3`, `Kirigami`, `PlasmaExtras`) — NOT raw QtQuick.Controls
- Plasmoid QML: no hardcoded colors — use `Kirigami.Theme.*`
- File naming: `PascalCase.qml`, `lowercase.cpp`, `lowercase.hpp`
- No formatter config — match surrounding code

## Testing Checklist

Before any commit:
- [ ] `cmake --build` succeeds with 0 errors
- [ ] Daemon starts: `systemctl --user start linuxpods-daemon`
- [ ] D-Bus responds: `gdbus call ... GetAll ...`
- [ ] Plasmoid loads without QML errors: `journalctl --user -t plasmashell | grep linuxpod`
- [ ] Click on tray icon opens popup
- [ ] Noise control switching works (both UI and actual AirPods)
- [ ] Battery levels display correctly
- [ ] Feature toggles send D-Bus commands

## Packaging

RPM spec (`linuxpods.spec`) produces two packages:
- `linuxpods` — daemon, CLI, D-Bus service, systemd unit
- `linuxpods-plasmoid` — Plasma 6 system tray widget

Key install paths (Fedora):
- `/usr/bin/linuxpods-daemon`
- `/usr/bin/librepods-ctl`
- `/usr/share/dbus-1/services/me.kavishdevar.linuxpods.service`
- `/usr/lib/systemd/user/linuxpods-daemon.service`
- `/usr/share/plasma/plasmoids/me.kavishdevar.linuxpods/`
