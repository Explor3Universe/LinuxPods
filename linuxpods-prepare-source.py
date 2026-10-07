#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later

"""Create the Fedora source archive from the checksum-pinned upstream release."""

import argparse
import gzip
import hashlib
import io
from pathlib import Path, PurePosixPath
import tarfile
import tempfile
from urllib.request import urlopen


VERSION = "1.0.2"
UPSTREAM_URL = (
    f"https://github.com/Explor3Universe/LinuxPods/archive/v{VERSION}/"
    f"linuxpods-{VERSION}.tar.gz"
)
UPSTREAM_SHA256 = "61d778de1adadf5aa981f2ab3505cea41e10c4e4619ad7a2d09b02384ff606bc"
ARCHIVE_ROOT = f"LinuxPods-{VERSION}"

# The Fedora build uses the daemon, CLI and Plasma widget only.
EXCLUDED_DIRECTORIES = (
    "design", "docs", "src/assets", "src/thirdparty", "src/translations",
)
EXCLUDED_FILES = {
    # Packaging is supplied separately in the SRPM.
    ".gitignore", "build.sh", "linuxpods.spec", "linuxpods.rpmlintrc",
    "src/main.cpp", "src/trayiconmanager.cpp", "src/trayiconmanager.h",
    "src/QRCodeImageProvider.hpp",
}


def excluded(path):
    return (
        path in EXCLUDED_FILES
        or any(path == directory or path.startswith(directory + "/")
               for directory in EXCLUDED_DIRECTORIES)
        or (PurePosixPath(path).parent == PurePosixPath("src")
            and path.endswith(".qml"))
    )


def prepare_source(data, output):
    digest = hashlib.sha256(data).hexdigest()
    if digest != UPSTREAM_SHA256:
        raise ValueError(f"upstream SHA256 mismatch: expected {UPSTREAM_SHA256}, got {digest}")

    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as upstream:
        members = []
        seen = set()
        removed = 0
        for member in upstream.getmembers():
            path = PurePosixPath(member.name)
            if (path.is_absolute() or ".." in path.parts
                    or not path.parts or path.parts[0] != ARCHIVE_ROOT):
                raise ValueError(f"unexpected archive path: {member.name}")
            if str(path) in seen or not (member.isfile() or member.isdir()):
                raise ValueError(f"unexpected archive entry: {member.name}")
            seen.add(str(path))
            relative = str(path.relative_to(ARCHIVE_ROOT))
            if excluded(relative):
                removed += member.isfile()
                continue
            members.append(member)

        output.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=output.parent, delete=False) as temporary:
            temporary_path = Path(temporary.name)
            try:
                with gzip.GzipFile(filename="", fileobj=temporary, mode="wb", compresslevel=9, mtime=0) as gz:
                    with tarfile.open(fileobj=gz, mode="w", format=tarfile.PAX_FORMAT) as archive:
                        for member in sorted(members, key=lambda entry: entry.name):
                            member.uid = member.gid = 0
                            member.uname = member.gname = ""
                            member.pax_headers = {}
                            # Keep upstream permissions, timestamps and file contents.
                            archive.addfile(member, upstream.extractfile(member) if member.isfile() else None)
                temporary.flush()
                temporary_path.chmod(0o644)
                temporary_path.replace(output)
            finally:
                temporary_path.unlink(missing_ok=True)
    return removed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version", choices=[VERSION])
    parser.add_argument("--upstream-archive", type=Path, help="use an already downloaded upstream archive")
    parser.add_argument("--output-dir", type=Path, default=Path("."))
    args = parser.parse_args()
    try:
        if args.upstream_archive:
            data = args.upstream_archive.read_bytes()
        else:
            with urlopen(UPSTREAM_URL, timeout=60) as response:
                data = response.read()
        output = args.output_dir / f"linuxpods-{VERSION}-fedora.tar.gz"
        removed = prepare_source(data, output)
    except (OSError, ValueError, tarfile.TarError) as error:
        parser.exit(1, f"Source preparation failed: {error}\n")
    print(f"Excluded {removed} unused files; retained files are unmodified.")
    print(f"{hashlib.sha256(output.read_bytes()).hexdigest()}  {output}")


if __name__ == "__main__":
    main()
