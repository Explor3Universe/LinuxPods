<!-- SPDX-License-Identifier: GPL-3.0-or-later -->

# Fedora review 2456922

Updated: 2026-10-07.

Review: https://bugzilla.redhat.com/show_bug.cgi?id=2456922

Reviewer: Andrei (`aradchen@redhat.com`). Comments 41 and 42 request
clarification of the noarch dependency and preparation of a filtered
source archive before SRPM creation. The bug is ASSIGNED with
`fedora-review?` and a needinfo request for the submitter. Sponsorship is
still needed unless arranged separately.

The last Bugzilla submission is **1.0.2-4**, commit `b198a83`, Copr build
10992106. The replacement **1.0.2-5** source archive, SRPM, Fedora 44 binary
packages and checksum manifest are published in the existing v1.0.2 GitHub
release. Anonymous downloads of all five assets were checked against the
local SHA256 values on 2026-10-07.

The user will submit the new Copr build, then request a final reply to the
reviewer. A Copr build and Bugzilla reply for 1.0.2-5 are still pending.

- Release: https://github.com/Explor3Universe/LinuxPods/releases/tag/v1.0.2
- SRPM: https://github.com/Explor3Universe/LinuxPods/releases/download/v1.0.2/linuxpods-1.0.2-5.fc44.src.rpm
- Source0: https://github.com/Explor3Universe/LinuxPods/releases/download/v1.0.2/linuxpods-1.0.2-fedora.tar.gz
- Checksums: https://github.com/Explor3Universe/LinuxPods/releases/download/v1.0.2/linuxpods-1.0.2-5-SHA256SUMS

## Candidate changes

- `linuxpods-prepare-source.py` verifies the original v1.0.2 SHA256 and
  produces a deterministic Fedora archive. GUI-only code, artwork, the
  bundled QR library, research material, mockups and duplicate upstream
  packaging helpers are excluded before SRPM creation.
- Both patches apply without fuzz. Retained upstream files are unchanged
  by repacking; the CMake patch keeps QR out of the daemon, and the
  documentation patch corrects the CLI and installation instructions.
- The noarch widget retains `Requires: linuxpods = version-release`.
  It explicitly requires `/usr/bin/gdbus` and `plasma5support`.
- `%check` runs the CLI and daemon on a private D-Bus session with temporary
  user directories and no access to host Bluetooth or audio services.
  CLI commands are observed through the daemon's D-Bus state.
- Both packages install the full GPL license and source-preparation notes.
- `build.sh` supports source-only and offline builds, copies the spec's
  declared inputs, and uses a fresh build directory rather than deleting
  a shared cache or previous output RPMs.

The widget's installed QML and metadata are byte-identical to the current
upstream tree. The Bluetooth implementation is unchanged by this revision.

## Verification performed

| Check | Result |
| --- | --- |
| Fedora 44 RPM/SRPM build without network access | Passed |
| Rebuild the Fedora 44 SRPM in clean Rawhide mock 6.9 | Passed; produced fc46 packages |
| CLI help, missing daemon, startup, D-Bus properties, CLI-to-D-Bus round trip | Passed in both builds and with installed packages |
| Clean Fedora 44 installation, dependency resolution, `rpm -V`, removal | Passed in a disposable container |
| `systemd-analyze --user --man=no verify` on installed unit | Passed |
| RPM scriptlet bodies versus expanded systemd user macros | Exact match after trimming surrounding whitespace |
| Rpmlint on all five RPMs and the spec, Fedora 44 and Rawhide | Zero errors and warnings, without project-specific filters |
| Rpmlint on installed Fedora 44 packages | Zero errors and warnings |
| Repacked archive on Python 3.14 and 3.15, repeated/offline/downloaded input | Identical SHA256 |
| Wrong upstream checksum | Rejected without overwriting an existing output archive |
| Contents, permissions and timestamps of all 41 retained source files | Match upstream |
| SRPM spec, patches and helper files | Match the working tree |
| Binary and debug packages | No excluded GUI, QR, artwork or presets |
| Binary ELF dependencies | No Qt GUI/Quick/Widgets linkage and no RPATH/RUNPATH |
| Noarch dependency metadata for x86_64, aarch64, ppc64le and s390x | Same versioned architecture-neutral dependency; metadata checks, not cross-architecture builds |
| Installed widget, license and service timestamps | Preserved for unmodified upstream files |

No fresh physical-AirPods or interactive Plasma test was performed for this
candidate. The user previously tested 1.0.2-4 on their laptop successfully.
These checks do not constitute formal Fedora approval or a complete new
fedora-review report. The reviewer still makes the manual review decisions.

Artifacts and detailed logs are collected under `out/`:

- `out/fedora-44/`: installable Fedora 44 packages and SRPM.
- `out/rawhide/`: packages rebuilt by mock for Rawhide.
- `out/release/`: source archive, Fedora 44 SRPM, spec, patches and helpers.
- `out/review/`: build, installation, lint and licensecheck evidence.

## Licensecheck and systemd findings

`licensecheck -r` on the old 1.0.2-4 sources after `%prep` reproduced exactly
seven unknown entries. Five are unused material now excluded from Source0:
`build.sh`, `linuxpods.rpmlintrc`, and the three files under `docs/`.

Two results remain and require explanation:

- `LICENSE` is the unchanged full GPL v3 text. Source SPDX headers and
  widget metadata specify `GPL-3.0-or-later`.
- `rpmbuild.env` is RPM-generated build metadata outside the upstream tree.

Do not alter the license text, invent copyright notices, or delete build
records to make the scanner appear clean. The detailed explanation ships
in `linuxpods-source-notes.md`.

The systemd check in fedora-review 0.12.0 was reproduced separately: its
regular expression reports failure even though the actual RPM scriptlets
match the current `%systemd_user_*` macro expansions. The installed user
unit passes systemd's own verifier.

## Next steps

1. Submit the published 1.0.2-5 SRPM to Copr and verify the enabled Fedora builds.
   No Copr API credentials are configured on this machine.
2. Once the build succeeds, prepare the final reply when requested by the
   user, using the draft below and adding the new Copr build URL. Clear
   the submitter's NEEDINFO using "I am providing the information requested
   of myself". Keep email notifications enabled.

Use a commit-pinned raw spec URL when possible, so future changes to main
cannot silently change the reviewed spec. Do not reuse Copr build 10992106
as evidence for 1.0.2-5: it contains 1.0.2-4.

## Working reply draft (finalize after Copr succeeds)

```text
Hi Andrei,

Thanks for the detailed review. I have prepared 1.0.2-5.

1. linuxpods-plasmoid is noarch and already has a fully versioned
   dependency: Requires: %{name} = %{version}-%{release}.
   I have kept it without %{?_isa}; the Requiring Base Package guideline
   specifies architecture-specific dependencies for non-noarch packages.

2. Source0 is now a filtered archive prepared before SRPM creation.
   The SRPM includes a standalone, checksum-pinned repacking script and
   documentation of every excluded path. The upstream v1.0.2 tag remains
   unchanged. The excluded content is absent from the source RPM itself,
   rather than only being removed during %prep.

I reproduced the seven UNKNOWN licensecheck entries locally. Five were
unused packaging/research files and are now excluded. The remaining two
are the full GPL license text (LICENSE, preserved and installed with
%license) and RPM's generated rpmbuild.env outside the upstream tree.
The retained sources and widget metadata declare GPL-3.0-or-later.

The systemd user macros are present in %post, %preun and %postun. I checked
the actual RPM scriptlets against their expansions and verified the user
unit with systemd-analyze; the fedora-review 0.12.0 regex still produces
the warning.

The new SRPM rebuilds successfully in Rawhide mock. The Fedora 44 packages
also pass installation/removal and isolated CLI/D-Bus checks. Rpmlint on
the RPMs and spec reports zero errors and warnings with the stock Fedora
configuration.

Spec URL: https://raw.githubusercontent.com/Explor3Universe/LinuxPods/main/linuxpods.spec
SRPM URL: https://github.com/Explor3Universe/LinuxPods/releases/download/v1.0.2/linuxpods-1.0.2-5.fc44.src.rpm

[fedora-review-service-build]
```
