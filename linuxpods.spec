Name:           linuxpods
Version:        1.0.2
Release:        3%{?dist}
Summary:        AirPods control daemon and KDE Plasma 6 widget

License:        GPL-3.0-or-later AND MIT
URL:            https://github.com/Explor3Universe/LinuxPods
Source0:        %{url}/archive/v%{version}/%{name}-%{version}.tar.gz
Source1:        %{name}.rpmlintrc

BuildRequires:  cmake >= 3.16
BuildRequires:  gcc-c++
BuildRequires:  cmake(Qt6Core)
BuildRequires:  cmake(Qt6Bluetooth)
BuildRequires:  cmake(Qt6DBus)
BuildRequires:  cmake(Qt6Network)
BuildRequires:  pkgconfig(openssl)
BuildRequires:  pkgconfig(libpulse)
BuildRequires:  systemd-rpm-macros

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
user unit, the D-Bus session activation file, and the linuxpods
command-line client. Install the linuxpods-plasmoid sub-package for the
native KDE Plasma 6 system tray widget.

Features:
  * Battery status (left earbud, right earbud, case, headset)
  * Active Noise Cancellation, Transparency, Adaptive modes
  * Ear detection with auto pause/play
  * Conversational Awareness
  * D-Bus API for scripting and integration
  * Command-line control tool (linuxpods)

%package        plasmoid
Summary:        KDE Plasma 6 system tray widget for LinuxPods
BuildArch:      noarch
Requires:       %{name} = %{version}-%{release}
Requires:       plasma-workspace

%description    plasmoid
Native KDE Plasma 6 system tray widget for LinuxPods. Provides a
compact tray icon with battery percentage and a full popup with noise
control, feature toggles, and settings. Communicates with
linuxpods-daemon over D-Bus.

%prep
%autosetup -n LinuxPods-%{version}

%conf
pushd src
%cmake -DLINUXPODS_BUILD_GUI=OFF
popd

%build
pushd src
%cmake_build
popd

%install
pushd src
%cmake_install
popd
install -Dpm 0644 data/man/linuxpods-daemon.1 %{buildroot}%{_mandir}/man1/linuxpods-daemon.1
install -Dpm 0644 data/man/linuxpods.1        %{buildroot}%{_mandir}/man1/linuxpods.1

%check
test -x %{buildroot}%{_bindir}/linuxpods-daemon
test -x %{buildroot}%{_bindir}/linuxpods

%post
%systemd_user_post linuxpods-daemon.service

%preun
%systemd_user_preun linuxpods-daemon.service

%postun
%systemd_user_postun_with_restart linuxpods-daemon.service

%files
%license LICENSE
%doc README.md
%{_bindir}/linuxpods-daemon
%{_bindir}/linuxpods
%{_mandir}/man1/linuxpods-daemon.1*
%{_mandir}/man1/linuxpods.1*
%{_datadir}/dbus-1/services/io.github.Explor3Universe.LinuxPods.service
%{_userunitdir}/linuxpods-daemon.service

%files plasmoid
%license LICENSE
%doc README.md
%{_datadir}/plasma/plasmoids/io.github.Explor3Universe.LinuxPods/

%changelog
* Thu Apr 16 2026 Nikita Sizikov <nixs.code@gmail.com> - 1.0.2-3
- License tag: GPL-3.0-or-later AND MIT (bundled qr-code-generator is MIT)
- Plasmoid subpackage: drop %%{?_isa} from Requires (noarch can't depend
  on arch-specific, breaks multiarch installability)
- Add missing BuildRequires: cmake(Qt6Network) for QLocalSocket in CLI

* Thu Apr 16 2026 Nikita Sizikov <nixs.code@gmail.com> - 1.0.2-2
- Address Fedora reviewer feedback (rhbz#2456922, comment 20):
  - Source0 URL switched to canonical git-tag format per SourceURL
    guideline (archive/v%%{version}/ instead of archive/refs/tags/)
  - BuildRequires converted to cmake() and pkgconfig() virtual provides
  - %%build split into %%conf + %%build per Fedora CMake macro convention
  - Changelog author updated with contactable email, dropped %%{?dist}
  - Removed 90-linuxpods.preset — user presets are not allowed in
    individual packages per Fedora DefaultServices policy
  - Cleaned up section comments

* Wed Apr 15 2026 Nikita Sizikov <nixs.code@gmail.com> - 1.0.2-1
- Fix click-to-expand on the Plasma tray icon (rhbz#2456922, comment 17)
- Add Conversational Awareness controls to the CLI (ca:on / ca:off)

* Mon Apr 13 2026 Nikita Sizikov <nixs.code@gmail.com> - 1.0.1-1
- Fix CLI socket bug, rebrand to LinuxPods (rhbz#2456922, comment 11)

* Sat Apr 11 2026 Nikita Sizikov <nixs.code@gmail.com> - 1.0.0-1
- First tagged upstream release, fix upstream URL (rhbz#2456922)

* Fri Apr 10 2026 Nikita Sizikov <nixs.code@gmail.com> - 0.2.0-2
- Address initial Fedora review feedback (rhbz#2456922)

* Thu Apr 09 2026 Nikita Sizikov <nixs.code@gmail.com> - 0.2.0-1
- Initial package
