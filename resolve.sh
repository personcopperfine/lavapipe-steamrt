#!/bin/bash
# Prints GitHub step outputs: tag=<upstream tag> build=<true|false>.
# build=false when a release for that tag already exists with our REVISION.
set -euo pipefail
. ./track.env

tag="${INPUT_REF:-}"
if [ -z "$tag" ]; then
    tag="$(git ls-remote --tags --refs https://gitlab.freedesktop.org/mesa/mesa.git "$MESA_TRACK" \
        | sed 's|.*refs/tags/||' | sort -V | tail -1)"
    # sort -V puts mesa-X.Y.Z-rcN after mesa-X.Y.Z; prefer the final release once it exists.
    final="${tag%-rc*}"
    if [ "$final" != "$tag" ] && git ls-remote --exit-code --tags --refs \
        https://gitlab.freedesktop.org/mesa/mesa.git "refs/tags/$final" >/dev/null; then
        tag="$final"
    fi
fi
[ -n "$tag" ] || { echo "no upstream tag matches $MESA_TRACK" >&2; exit 1; }

rev="$(cat REVISION)"
build=true
if [ "${FORCE:-false}" != true ] \
    && gh release view "$tag" --json body -q .body 2>/dev/null | grep -qx "revision=$rev"; then
    build=false
fi

echo "upstream=$tag revision=$rev build=$build" >&2
echo "tag=$tag"
echo "build=$build"
