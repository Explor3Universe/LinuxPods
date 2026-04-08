Name:           linuxpods
Version:        0.1.0
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

Requires:       qt6-qtbase
Requires:       qt6-qtconnectivity
Requires:       qt6-qtmultimedia
Requires:       qt6-qtdeclarative
Requires:       kf6-kstatusnotifieritem
Requires:       openssl-libs
Requires:       pulseaudio-libs
Requires:       bluez

%description
LinuxPods is a Fedora/RHEL fork of LibrePods — a native Linux application
that unlocks Apple AirPods features on non-Apple devices via the
reverse-engineered Apple Accessory Protocol (AAP) over L2CAP.

This package builds the bundled (vendored) source tree under src/, which
allows local modifications to the UI (QML) and core logic without
depending on a remote upstream snapshot.

Features:
  * Battery status (left earbud, right earbud, case)
  * Active Noise Cancellation, Transparency, Adaptive modes
  * Ear detection (auto pause/play)
  * Conversational Awareness
  * Connection notifications
  * KDE/Qt6 system tray integration

Tested on AirPods Pro 2 (USB-C, 2024) on Fedora 43 + KDE Plasma 6.

Upstream project: https://github.com/kavishdevar/librepods

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

%files
%license LICENSE
%doc README.md
%{_bindir}/librepods
%{_bindir}/librepods-ctl
%{_datadir}/applications/me.kavishdevar.librepods.desktop
%{_datadir}/icons/hicolor/scalable/apps/librepods.svg
%{_datadir}/librepods/translations/librepods_tr.qm

%changelog
* Wed Apr 08 2026 Nick <noreply@github.com> - 0.1.0-1
- Switch to vendored source tree under src/
- Allows local UI/QML modifications without upstream dependency
- Initial fork from upstream librepods commit 1f2d707
