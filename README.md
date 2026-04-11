<!-- SPDX-License-Identifier: GPL-3.0-or-later -->

# LinuxPods

Native AirPods integration for Linux. Battery monitoring, noise control, ear detection, and more — as a native KDE Plasma 6 system tray widget.

Built on the reverse-engineered Apple Accessory Protocol (AAP) over L2CAP.

## Features

- Battery status (left, right, case, AirPods Max headset)
- Noise control: ANC / Transparency / Adaptive / Off
- Ear detection with auto-pause/play
- Conversational Awareness
- One Bud ANC mode
- Hearing Aid mode
- Connection notifications
- Native KDE Plasma 6 system tray widget
- D-Bus API for scripting and integration
- CLI tool (`librepods-ctl`)

Tested on **AirPods Pro 2 USB-C (2024)**, Fedora 43 + KDE Plasma 6 + Wayland.

## Architecture

```
linuxpods-daemon          Headless C++ backend (BLE, AAP protocol, media)
       │
       │ D-Bus: me.kavishdevar.linuxpods
       │
  Plasma plasmoid         Native system tray widget (QML)
```

The daemon manages AirPods connections and exposes state over D-Bus. The Plasma plasmoid displays battery, controls noise modes, and toggles features — all through the D-Bus interface.

## Installation

### From RPM (Fedora)

```bash
sudo dnf install ./linuxpods-1.0.0-1.fc43.x86_64.rpm ./linuxpods-plasmoid-1.0.0-1.fc43.x86_64.rpm
systemctl --user enable --now linuxpods-daemon
```

The plasmoid appears in the system tray automatically when AirPods connect.

### Build from source

```bash
git clone https://github.com/Explor3Universe/LinuxPods.git
cd LinuxPods

# RPM build
./build.sh                # installs build dependencies via dnf
./build.sh --skip-deps    # if deps already installed
sudo dnf install out/linuxpods-1.0.0-*.rpm out/linuxpods-plasmoid-1.0.0-*.rpm

# Or local build without RPM
cmake -S src -B build
cmake --build build -j$(nproc)
./build/linuxpods-daemon
```

### Build dependencies

- cmake >= 3.16, gcc-c++
- qt6-qtbase-devel, qt6-qtconnectivity-devel, qt6-qtdeclarative-devel, qt6-qttools-devel
- kf6-kstatusnotifieritem-devel
- openssl-devel, pulseaudio-libs-devel

## Usage

### Daemon

```bash
systemctl --user enable --now linuxpods-daemon   # start + autostart
systemctl --user status linuxpods-daemon         # check status
journalctl --user -u linuxpods-daemon -f         # live logs
```

### CLI

```bash
librepods-ctl noise:anc           # Active Noise Cancellation
librepods-ctl noise:transparency  # Transparency mode
librepods-ctl noise:adaptive      # Adaptive mode
librepods-ctl noise:off           # Off
```

### D-Bus

```bash
# Read all properties
gdbus call --session -d me.kavishdevar.linuxpods \
  -o /me/kavishdevar/linuxpods \
  -m org.freedesktop.DBus.Properties.GetAll \
  me.kavishdevar.linuxpods.Manager

# Set noise control mode (0=Off, 1=ANC, 2=Transparency, 3=Adaptive)
gdbus call --session -d me.kavishdevar.linuxpods \
  -o /me/kavishdevar/linuxpods \
  -m me.kavishdevar.linuxpods.Manager.SetNoiseControlMode 3
```

## Project Structure

```
src/
  service/linuxpodsservice.*    Backend logic (BLE, AAP, media, settings)
  dbus/linuxpodsdbusadaptor.h   D-Bus interface adaptor
  daemon/main.cpp               Headless daemon entry point
  main.cpp                      Standalone GUI (fallback for non-Plasma)
  airpods_packets.h             AAP protocol definitions
  deviceinfo.hpp                Device state model
  battery.hpp                   Battery state model
  ble/                          BLE scanning
  media/                        MPRIS + PulseAudio

plasmoid/
  metadata.json                 Plasma 6 widget metadata
  contents/ui/                  QML widget files

data/
  linuxpods-daemon.service      Systemd user service
  me.kavishdevar.linuxpods.service  D-Bus activation
```

## Packages

The RPM spec produces two packages:

| Package | Contents |
|---------|----------|
| `linuxpods` | Daemon, CLI, D-Bus service, systemd unit |
| `linuxpods-plasmoid` | KDE Plasma 6 system tray widget |

## License

**GPL-3.0-or-later**

Based on [LibrePods](https://github.com/kavishdevar/librepods) by kavishdevar.
