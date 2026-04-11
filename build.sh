#!/usr/bin/env bash
# Build LinuxPods RPM from the vendored source tree under ./src/.
# Usage: ./build.sh [--skip-deps]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPEC="$SCRIPT_DIR/linuxpods.spec"
SRC_DIR="$SCRIPT_DIR/src"
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
if [[ ! -d "$SRC_DIR" ]]; then
    echo "ERROR: $SRC_DIR not found — vendored sources missing" >&2
    exit 1
fi

# Read Name and Version from the spec.
NAME=$(awk '/^Name:/    {print $2; exit}' "$SPEC")
VERSION=$(awk '/^Version:/ {print $2; exit}' "$SPEC")
TARBALL="${NAME}-${VERSION}.tar.gz"
# Inner directory name — mirrors the GitHub release archive layout
# (%{URL}/archive/refs/tags/v${VERSION}.tar.gz expands to LinuxPods-${VERSION}/)
# so the spec's %autosetup and %build steps are identical whether the
# source is produced locally or fetched from a tagged upstream release.
TARBALL_DIR="LinuxPods-${VERSION}"

echo ">>> Preparing rpmbuild tree at $TOPDIR"
mkdir -p "$TOPDIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
mkdir -p "$OUTDIR"

echo ">>> Building source tarball from $SCRIPT_DIR"
tar czf "$TOPDIR/SOURCES/$TARBALL" \
    --transform="s|^|${TARBALL_DIR}/|" \
    -C "$SCRIPT_DIR" \
    src plasmoid data LICENSE README.md

echo ">>> Tarball:"
ls -la "$TOPDIR/SOURCES/$TARBALL"

# Source1 — rpmlintrc filter file consumed by rpmlint during review.
if [[ -f "$SCRIPT_DIR/${NAME}.rpmlintrc" ]]; then
    cp "$SCRIPT_DIR/${NAME}.rpmlintrc" "$TOPDIR/SOURCES/"
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
rm -f "$OUTDIR"/*.rpm
find "$TOPDIR/RPMS" -name '*.rpm' -exec cp -v {} "$OUTDIR/" \;
find "$TOPDIR/SRPMS" -name '*.rpm' -exec cp -v {} "$OUTDIR/" \;

echo ""
echo "Done. Built RPMs:"
ls -1 "$OUTDIR"/*.rpm
echo ""
echo "Install with:  sudo dnf install $OUTDIR/${NAME}-${VERSION}-*.x86_64.rpm"
