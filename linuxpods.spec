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
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  qt6-qttools-devel
BuildRequires:  kf6-kstatusnotifieritem-devel
BuildRequires:  openssl-devel
BuildRequires:  pulseaudio-libs-devel
BuildRequires:  pkgconfig
BuildRequires:  systemd-rpm-macros
BuildRequires:  desktop-file-utils
BuildRequires:  libappstream-glib

# Runtime deps auto-detected from ELF linkage, except bluez (no .so link)
Requires:       bluez

%description
LinuxPods is a native Linux application that unlocks Apple AirPods
features on non-Apple devices via the reverse-engineered Apple Accessory
Protocol (AAP) over L2CAP.

Provides a headless daemon (linuxpods-daemon) that manages AirPods
connections, BLE scanning, media integration, and settings. Exposes
a D-Bus interface for desktop frontends.

Features:
  * Battery status (left earbud, right earbud, case, headset)
  * Active Noise Cancellation, Transparency, Adaptive modes
  * Ear detection with auto pause/play
  * Conversational Awareness
  * D-Bus API for scripting and integration
  * CLI tool (librepods-ctl)

# ── Plasmoid subpackage ──────────────────────────────────────────────
%package        plasmoid
Summary:        KDE Plasma 6 system tray widget for LinuxPods
Requires:       %{name} = %{version}-%{release}

%description    plasmoid
Native KDE Plasma 6 system tray widget for LinuxPods. Provides a
compact tray icon with battery percentage and a full popup with noise
control, feature toggles, and settings. Communicates with
linuxpods-daemon over D-Bus.

%prep
%autosetup -n %{name}-%{version}

%build
%cmake
%cmake_build

%install
%cmake_install
desktop-file-validate %{buildroot}%{_datadir}/applications/me.kavishdevar.librepods.desktop
appstream-util validate-relax --nonet %{buildroot}%{_metainfodir}/me.kavishdevar.linuxpods.metainfo.xml

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
%{_userunitdir}/linuxpods-daemon.service
%{_userpresetdir}/90-linuxpods.preset
%{_metainfodir}/me.kavishdevar.linuxpods.metainfo.xml
%{_datadir}/librepods/translations/librepods_tr.qm

# ── Plasmoid subpackage files ────────────────────────────────────────
%files plasmoid
%{_datadir}/plasma/plasmoids/me.kavishdevar.linuxpods/

%changelog
* Thu Apr 09 2026 Nick <noreply@github.com> - 0.2.0-1
- Architecture split: headless daemon + Plasma 6 plasmoid
- Add D-Bus interface (me.kavishdevar.linuxpods.Manager)
- Add systemd user service and D-Bus activation
- Add native Plasma 6 system tray widget (linuxpods-plasmoid)
- Fix critical bugs: use-after-free, double-free, socket leaks
- Add AppStream metainfo for Fedora guidelines compliance
