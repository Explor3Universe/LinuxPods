<!-- SPDX-License-Identifier: GPL-3.0-or-later -->

# LinuxPods

Native AirPods integration for Linux. Battery monitoring, noise control, ear detection, and more — as a native KDE Plasma 6 system tray widget.

Built on the reverse-engineered Apple Accessory Protocol (AAP) over L2CAP.
The backend derives from [LibrePods](https://github.com/kavishdevar/librepods).

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
- CLI tool (`linuxpods`)

Tested on **AirPods Pro 2 USB-C (2024)**, Fedora 43 + KDE Plasma 6 + Wayland.

## Architecture

```
linuxpods-daemon          Headless C++ backend (BLE, AAP protocol, media)
       │
       │ D-Bus: io.github.Explor3Universe.LinuxPods
       │
  Plasma plasmoid         Native system tray widget (QML)
```

The daemon manages AirPods connections and exposes state over D-Bus. The Plasma plasmoid displays battery, controls noise modes, and toggles features — all through the D-Bus interface.

## Installation

### From Copr (Fedora)

```bash
sudo dnf copr enable explor3universe/linuxpods
sudo dnf install linuxpods linuxpods-plasmoid
systemctl --user enable --now linuxpods-daemon
```

The plasmoid appears in the system tray automatically when AirPods connect.
Pair the AirPods in the desktop Bluetooth settings first. LinuxPods manages
already-connected devices; it does not perform Bluetooth pairing.

### Build from source

```bash
git clone https://github.com/Explor3Universe/LinuxPods.git
cd LinuxPods

# RPM build
./build.sh                # installs build dependencies via dnf
./build.sh --skip-deps    # if deps already installed
./build.sh --srpm-only    # source RPM only

# Or local build without RPM
cmake -S src -B build -DLINUXPODS_BUILD_GUI=OFF
cmake --build build -j$(nproc)
./build/linuxpods-daemon
```

For a local installation, pass the two matching binary RPMs from `out/`
(`linuxpods` for your architecture and `linuxpods-plasmoid.noarch`) to
`sudo dnf install`. Source and debug RPMs are not needed for normal use.

The RPM build prepares a checksum-pinned, filtered upstream archive. See
`linuxpods-source-notes.md`, also shipped as package documentation, for
the exact exclusions and offline source-preparation command.

### Build dependencies

- cmake >= 3.16, gcc-c++
- qt6-qtbase-devel, qt6-qtconnectivity-devel
- openssl-devel, pulseaudio-libs-devel
- RPM builds also use rpm-build, systemd-rpm-macros, python3, dbus-daemon and glib2

The standalone Qt GUI is deprecated and excluded from Fedora's source
archive and binary packages. The supported Fedora interface is the Plasma
widget, which uses Plasma 6, plasma5support and the `gdbus` command.

## Usage

### Daemon

```bash
systemctl --user enable --now linuxpods-daemon   # start + autostart
systemctl --user status linuxpods-daemon         # check status
journalctl --user -u linuxpods-daemon -f         # live logs
```

### CLI

```bash
linuxpods noise:anc           # Active Noise Cancellation
linuxpods noise:transparency  # Transparency mode
linuxpods noise:adaptive      # Adaptive mode
linuxpods noise:off           # Off
linuxpods ca:on               # Enable Conversational Awareness
linuxpods ca:off              # Disable Conversational Awareness
linuxpods --help
```

The v1.0.2 CLI uses a one-way local socket. A zero exit status does not
confirm that AirPods are connected or that a command was applied. Use the
widget or D-Bus properties to check device state.

### D-Bus

```bash
# Read all properties
gdbus call --session -d io.github.Explor3Universe.LinuxPods \
  -o /io/github/Explor3Universe/LinuxPods \
  -m org.freedesktop.DBus.Properties.GetAll \
  io.github.Explor3Universe.LinuxPods.Manager

# Set noise control mode (0=Off, 1=ANC, 2=Transparency, 3=Adaptive)
gdbus call --session -d io.github.Explor3Universe.LinuxPods \
  -o /io/github/Explor3Universe/LinuxPods \
  -m io.github.Explor3Universe.LinuxPods.Manager.SetNoiseControlMode 3
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
  io.github.Explor3Universe.LinuxPods.service  D-Bus activation
```

## Packages

The RPM spec produces two packages:

| Package | Contents |
|---------|----------|
| `linuxpods` | Daemon, CLI, D-Bus service, systemd unit |
| `linuxpods-plasmoid` | KDE Plasma 6 system tray widget |
