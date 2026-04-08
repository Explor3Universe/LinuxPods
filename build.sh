#!/usr/bin/env bash
# Build LinuxPods RPM from upstream librepods.
# Usage: ./build.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPEC="$SCRIPT_DIR/linuxpods.spec"
OUTDIR="$SCRIPT_DIR/out"

# rpmbuild + cmake misbehave when paths contain spaces. Build in a
# space-free temp dir, then copy artifacts back to OUTDIR.
TOPDIR="${LINUXPODS_BUILD_DIR:-$HOME/.cache/linuxpods-rpmbuild}"
if [[ "$TOPDIR" == *" "* ]]; then
    echo "ERROR: TOPDIR contains spaces ($TOPDIR). Set LINUXPODS_BUILD_DIR to a space-free path." >&2
    exit 1
fi

SKIP_DEPS=0
for arg in "$@"; do
    case "$arg" in
        --skip-deps) SKIP_DEPS=1 ;;
        -h|--help)
            echo "Usage: $0 [--skip-deps]"
            echo "  --skip-deps   Skip 'sudo dnf builddep' step (use if BuildRequires are already installed)"
            exit 0
            ;;
    esac
done

if [[ ! -f "$SPEC" ]]; then
    echo "ERROR: $SPEC not found" >&2
    exit 1
fi

# Extract upstream commit hash from spec (simple grep — works on any rpm version).
COMMIT=$(grep -oP '^%global commit \K\S+' "$SPEC")
if [[ -z "$COMMIT" ]]; then
    echo "ERROR: could not extract commit hash from $SPEC" >&2
    exit 1
fi
SHORTCOMMIT="${COMMIT:0:7}"
UPSTREAM="librepods"
TARBALL="${UPSTREAM}-${SHORTCOMMIT}.tar.gz"
TARBALL_URL="https://github.com/kavishdevar/${UPSTREAM}/archive/${COMMIT}/${TARBALL}"

echo ">>> Preparing rpmbuild tree at $TOPDIR"
mkdir -p "$TOPDIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
mkdir -p "$OUTDIR"

if [[ ! -f "$TOPDIR/SOURCES/$TARBALL" ]]; then
    echo ">>> Downloading $TARBALL_URL"
    curl -fL --retry 3 -o "$TOPDIR/SOURCES/$TARBALL" "$TARBALL_URL"
else
    echo ">>> Using cached $TOPDIR/SOURCES/$TARBALL"
fi

cp "$SPEC" "$TOPDIR/SPECS/"

if [[ $SKIP_DEPS -eq 0 ]]; then
    echo ">>> Installing build dependencies (sudo dnf builddep)"
    sudo dnf builddep -y "$SPEC"
else
    echo ">>> Skipping dnf builddep (--skip-deps)"
fi

echo ">>> Running rpmbuild"
rpmbuild --define "_topdir $TOPDIR" -ba "$TOPDIR/SPECS/$(basename "$SPEC")"

echo ">>> Collecting artifacts to $OUTDIR"
find "$TOPDIR/RPMS" -name '*.rpm' -exec cp -v {} "$OUTDIR/" \;
find "$TOPDIR/SRPMS" -name '*.rpm' -exec cp -v {} "$OUTDIR/" \;

echo ""
echo "Done. Built RPMs:"
ls -1 "$OUTDIR"/*.rpm
echo ""
echo "Install with:  sudo dnf install $OUTDIR/linuxpods-*.x86_64.rpm"
