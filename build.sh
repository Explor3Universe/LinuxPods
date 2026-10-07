#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Build Fedora RPMs from the checksum-pinned, repacked upstream release.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPEC="$SCRIPT_DIR/linuxpods.spec"
OUTDIR="${LINUXPODS_OUTDIR:-$SCRIPT_DIR/out}"

# rpmbuild + cmake misbehave when paths contain spaces. Build in a
# space-free temp dir, then copy artifacts back to OUTDIR.
BUILD_BASE="${LINUXPODS_BUILD_DIR:-$HOME/.cache/linuxpods-rpmbuild}"
if [[ "$BUILD_BASE" == *[[:space:]]* ]]; then
    echo "ERROR: Set LINUXPODS_BUILD_DIR to a path without whitespace." >&2
    exit 1
fi

SKIP_DEPS=0
MODE=-ba
SOURCE_ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-deps) SKIP_DEPS=1 ;;
        --srpm-only) MODE=-bs; SKIP_DEPS=1 ;;
        --source-archive)
            [[ $# -ge 2 ]] || { echo "ERROR: --source-archive needs a path" >&2; exit 2; }
            SOURCE_ARGS=(--upstream-archive "$2")
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--skip-deps] [--srpm-only] [--source-archive FILE]"
            echo "  --skip-deps   Skip 'sudo dnf builddep' step (use if BuildRequires are already installed)"
            echo "  --srpm-only   Create only the source RPM (requires rpm-build and python3)"
            echo "  --source-archive FILE   Repack a local upstream archive instead of downloading it"
            exit 0
            ;;
        *) echo "ERROR: Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

if [[ ! -f "$SPEC" ]]; then
    echo "ERROR: $SPEC not found" >&2
    exit 1
fi
for tool in rpmbuild rpmspec python3; do
    command -v "$tool" >/dev/null || { echo "ERROR: $tool is required" >&2; exit 1; }
done

NAME=$(rpmspec -q --srpm --queryformat '%{NAME}' "$SPEC")
VERSION=$(rpmspec -q --srpm --queryformat '%{VERSION}' "$SPEC")
TARBALL="${NAME}-${VERSION}-fedora.tar.gz"

mkdir -p "$BUILD_BASE"
BUILD_BASE=$(cd "$BUILD_BASE" && pwd -P)
if [[ "$BUILD_BASE" == *[[:space:]]* ]]; then
    echo "ERROR: LINUXPODS_BUILD_DIR resolves to a path containing whitespace." >&2
    exit 1
fi
TOPDIR=$(mktemp -d "$BUILD_BASE/build.XXXXXX")
echo ">>> Preparing rpmbuild tree at $TOPDIR"
mkdir -p "$TOPDIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
mkdir -p "$OUTDIR"

python3 "$SCRIPT_DIR/linuxpods-prepare-source.py" "$VERSION" \
    "${SOURCE_ARGS[@]}" --output-dir "$TOPDIR/SOURCES"

# Copy exactly the additional sources and patches declared by the spec.
rpmspec --parse "$SPEC" > "$TOPDIR/expanded.spec"
while read -r source; do
    file=${source##*/}
    [[ "$file" == "$TARBALL" ]] && continue
    cp -pv "$SCRIPT_DIR/$file" "$TOPDIR/SOURCES/"
done < <(awk '/^(Source[0-9]*|Patch[0-9]*):/ {print $2}' "$TOPDIR/expanded.spec")

cp -p "$SPEC" "$TOPDIR/SPECS/"

if [[ $SKIP_DEPS -eq 0 ]]; then
    echo ">>> Installing build dependencies (sudo dnf builddep)"
    if [[ $EUID -eq 0 ]]; then
        dnf builddep -y "$SPEC"
    else
        sudo dnf builddep -y "$SPEC"
    fi
else
    echo ">>> Skipping dnf builddep (--skip-deps)"
fi

echo ">>> Running rpmbuild"
rpmbuild --define "_topdir $TOPDIR" "$MODE" "$TOPDIR/SPECS/$(basename "$SPEC")"

echo ">>> Collecting artifacts to $OUTDIR"
find "$TOPDIR/RPMS" "$TOPDIR/SRPMS" -name '*.rpm' -exec cp -pv {} "$OUTDIR/" \;
cp -p "$TOPDIR/SOURCES/$TARBALL" "$OUTDIR/"

echo ""
echo "Done. Artifacts: $OUTDIR"
echo "Build tree: $TOPDIR"
