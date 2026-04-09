Name:           linuxpods
Version:        0.2.0
Release:        1%{?dist}
Summary:        AirPods control and battery monitor for Linux (KDE/Qt6)

License:        GPL-3.0-or-later
URL:            https://github.com/Puerh0x1/LinuxPods
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  cmake >= 3.16
BuildRequires:  gcc-c++
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtconnectivity-devel
BuildRequires:  qt6-qtmultimedia-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  qt6-qttools-devel
BuildRequires:  kf6-kstatusnotifieritem-devel
BuildRequires:  openssl-devel
BuildRequires:  pulseaudio-libs-devel
BuildRequires:  pkgconfig
BuildRequires:  systemd-rpm-macros

Requires:       qt6-qtbase
Requires:       qt6-qtconnectivity
Requires:       qt6-qtmultimedia
Requires:       qt6-qtdeclarative
Requires:       kf6-kstatusnotifieritem
Requires:       openssl-libs
Requires:       pulseaudio-libs
Requires:       bluez

%description
LinuxPods is a native Linux application that unlocks Apple AirPods
features on non-Apple devices via the reverse-engineered Apple Accessory
Protocol (AAP) over L2CAP.

This package provides the headless daemon (linuxpods-daemon) that manages
AirPods connections, BLE scanning, media integration, and settings.
It exposes a D-Bus interface at me.kavishdevar.linuxpods for frontends.

Also includes the standalone GUI (librepods) for non-Plasma desktops
and the CLI tool (librepods-ctl) for scripting.

Features:
  * Battery status (left earbud, right earbud, case, headset)
  * Active Noise Cancellation, Transparency, Adaptive modes
  * Ear detection (auto pause/play)
  * Conversational Awareness
  * Connection notifications
  * D-Bus API for desktop integration

Tested on AirPods Pro 2 (USB-C, 2024) on Fedora 43 + KDE Plasma 6.

# ── Plasmoid subpackage ──────────────────────────────────────────────
%package        plasmoid
Summary:        KDE Plasma 6 system tray widget for LinuxPods
Requires:       %{name} = %{version}-%{release}
Requires:       libplasma
Requires:       kf6-kirigami
Requires:       qt6-qt5compat

%description    plasmoid
Native KDE Plasma 6 system tray widget for LinuxPods. Provides
a compact tray icon with battery percentage and a full popup with
noise control, feature toggles, and settings.

Communicates with the linuxpods-daemon over D-Bus.

%prep
%autosetup -n %{name}-%{version}

%build
mkdir -p build
cd build
cmake .. \
    -DCMAKE_INSTALL_PREFIX=%{_prefix} \
    -DCMAKE_INSTALL_BINDIR=%{_bindir} \
    -DCMAKE_INSTALL_LIBDIR=%{_libdir} \
    -DCMAKE_INSTALL_DATAROOTDIR=%{_datadir} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_VERBOSE_MAKEFILE=OFF
make %{?_smp_mflags}

%install
cd build
make install DESTDIR=%{buildroot}

%post
%systemd_user_post linuxpods-daemon.service

%preun
%systemd_user_preun linuxpods-daemon.service

%postun
%systemd_user_postun_with_restart linuxpods-daemon.service

# ── Main package files ───────────────────────────────────────────────
%files
%license LICENSE
%doc README.md
%{_bindir}/linuxpods-daemon
%{_bindir}/librepods
%{_bindir}/librepods-ctl
%{_datadir}/applications/me.kavishdevar.librepods.desktop
%{_datadir}/icons/hicolor/scalable/apps/librepods.svg
%{_datadir}/dbus-1/services/me.kavishdevar.linuxpods.service
/usr/lib/systemd/user/linuxpods-daemon.service
%{_datadir}/librepods/translations/librepods_tr.qm

# ── Plasmoid subpackage files ────────────────────────────────────────
%files plasmoid
%{_datadir}/plasma/plasmoids/me.kavishdevar.linuxpods/

%changelog
* Thu Apr 10 2026 Nick <noreply@github.com> - 0.2.0-1
- Architecture split: headless daemon + Plasma 6 plasmoid
- Add D-Bus interface at me.kavishdevar.linuxpods
- Add systemd user service for daemon
- Add native Plasma 6 system tray widget (subpackage linuxpods-plasmoid)
- Standalone GUI kept as fallback for non-Plasma desktops

* Wed Apr 08 2026 Nick <noreply@github.com> - 0.1.0-1
- Switch to vendored source tree under src/
- Allows local UI/QML modifications without upstream dependency
- Initial fork from upstream librepods commit 1f2d707
