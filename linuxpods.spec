Name:           linuxpods
Version:        0.2.0
Release:        2%{?dist}
Summary:        AirPods control daemon and KDE Plasma 6 widget

License:        GPL-3.0-or-later
URL:            https://github.com/Puerh0x1/LinuxPods
# The upstream tarball is not currently published on a release page; it is
# produced from the vendored src/, plasmoid/ and data/ trees of the upstream
# repository via the ./build.sh helper (see the repository root). To generate
# it manually:
#   git clone %%{URL}.git linuxpods-%%{version}
#   tar czf linuxpods-%%{version}.tar.gz linuxpods-%%{version}
Source0:        %{URL}/%{name}-%{version}.tar.gz
Source1:        %{name}.rpmlintrc

BuildRequires:  cmake >= 3.16
BuildRequires:  gcc-c++
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtconnectivity-devel
BuildRequires:  openssl-devel
BuildRequires:  pulseaudio-libs-devel
BuildRequires:  pkgconfig
BuildRequires:  systemd-rpm-macros

# Runtime deps auto-detected from ELF linkage, except the following which
# do not appear as .so dependencies but are still required at runtime.
Requires:       bluez
Requires:       dbus-common

# Bundled third-party library (MIT licensed, upstream at
# https://www.nayuki.io/page/qr-code-generator-library). Kept vendored
# because Fedora does not currently package this project.
Provides:       bundled(qr-code-generator) = 1.8

%description
LinuxPods is a native Linux backend for Apple AirPods that exposes
battery, noise control, ear detection and related features through a
session D-Bus interface, using the reverse-engineered Apple Accessory
Protocol (AAP) over Bluetooth L2CAP.

This package ships the headless daemon (linuxpods-daemon), its systemd
user unit, the D-Bus session activation file, and the librepods-ctl
command-line client. Install the linuxpods-plasmoid sub-package for the
native KDE Plasma 6 system tray widget.

Features:
  * Battery status (left earbud, right earbud, case, headset)
  * Active Noise Cancellation, Transparency, Adaptive modes
  * Ear detection with auto pause/play
  * Conversational Awareness
  * D-Bus API for scripting and integration
  * Command-line control tool (librepods-ctl)

# ── Plasmoid subpackage ──────────────────────────────────────────────
%package        plasmoid
Summary:        KDE Plasma 6 system tray widget for LinuxPods
BuildArch:      noarch
Requires:       %{name}%{?_isa} = %{version}-%{release}
Requires:       plasma-workspace

%description    plasmoid
Native KDE Plasma 6 system tray widget for LinuxPods. Provides a
compact tray icon with battery percentage and a full popup with noise
control, feature toggles, and settings. Communicates with
linuxpods-daemon over D-Bus.

%prep
%autosetup -n %{name}-%{version}

%build
%cmake -DLINUXPODS_BUILD_GUI=OFF
%cmake_build

%install
%cmake_install
install -Dpm 0644 data/man/linuxpods-daemon.1 %{buildroot}%{_mandir}/man1/linuxpods-daemon.1
install -Dpm 0644 data/man/librepods-ctl.1    %{buildroot}%{_mandir}/man1/librepods-ctl.1

%check
# No upstream unit tests yet. As a smoke test, verify the installed
# binaries are present and executable.
test -x %{buildroot}%{_bindir}/linuxpods-daemon
test -x %{buildroot}%{_bindir}/librepods-ctl

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
%{_bindir}/librepods-ctl
%{_mandir}/man1/linuxpods-daemon.1*
%{_mandir}/man1/librepods-ctl.1*
%{_datadir}/dbus-1/services/me.kavishdevar.linuxpods.service
%{_userunitdir}/linuxpods-daemon.service
%{_userpresetdir}/90-linuxpods.preset

# ── Plasmoid subpackage files ────────────────────────────────────────
%files plasmoid
%license LICENSE
%doc README.md
%{_datadir}/plasma/plasmoids/me.kavishdevar.linuxpods/

%changelog
* Fri Apr 10 2026 Nick <noreply@github.com> - 0.2.0-2%{?dist}
- Address Fedora package review feedback (rhbz#2456922):
  - Source0 now uses %%{URL} prefix as required by SourceURL guideline
  - Add Requires: dbus-common for /usr/share/dbus-1 ownership
  - Use %%{?_isa} in plasmoid subpackage inter-package Requires
  - Strip RPATH from installed binaries (CMake + Qt fix)
  - Ship man pages for linuxpods-daemon and librepods-ctl
  - Add %%check section validating built binaries
  - Mark plasmoid subpackage BuildArch: noarch (pure QML)
  - Add rpmlintrc to filter legitimate project-name false positives
  - Declare bundled(qr-code-generator) Provides
  - Add SPDX-License-Identifier headers to all first-party sources
  - Drop the standalone Qt GUI front-end and the proprietary
    Apple SF Symbols font it depended on; the package now ships only the
    daemon, the CLI client and (via the subpackage) the Plasma 6 widget
  - Drop unused desktop file, application icon and metainfo together
    with the GUI to keep the package legally clean

* Thu Apr 09 2026 Nick <noreply@github.com> - 0.2.0-1%{?dist}
- Architecture split: headless daemon + Plasma 6 plasmoid
- Add D-Bus interface (me.kavishdevar.linuxpods.Manager)
- Add systemd user service and D-Bus activation
- Add native Plasma 6 system tray widget (linuxpods-plasmoid)
- Fix critical bugs: use-after-free, double-free, socket leaks
- Add AppStream metainfo for Fedora guidelines compliance
