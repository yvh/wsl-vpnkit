#!/usr/bin/env bash

set -euo pipefail

# Regenerate ./checksums from the sha256sums published with the
# gvisor-tap-vsock release pinned in the Dockerfile.
# With --check, fail instead of writing when ./checksums is out of date.

cd "$(dirname "$0")"

BINARIES=(gvforwarder gvproxy-windows.exe)
VERSION=$(sed -n 's/^ARG GVISOR_TAP_VSOCK_VERSION=//p' Dockerfile)
TEST_VERSION=$(sed -n 's/^ARG GVISOR_TAP_VSOCK_VERSION=//p' tests/docker/Dockerfile)

if [ -z "$VERSION" ]; then
    echo "GVISOR_TAP_VSOCK_VERSION not found in Dockerfile" >&2
    exit 1
fi
if [ "$VERSION" != "$TEST_VERSION" ]; then
    echo "gvisor-tap-vsock version mismatch: Dockerfile=$VERSION tests/docker/Dockerfile=$TEST_VERSION" >&2
    exit 1
fi

sums=$(curl -fsSL "https://github.com/containers/gvisor-tap-vsock/releases/download/${VERSION}/sha256sums")
expected=$(for bin in "${BINARIES[@]}"; do
    line=$(awk -v f="$bin" '$2 == f || $2 == "*" f' <<< "$sums")
    if [ -z "$line" ]; then
        echo "$bin not found in sha256sums for $VERSION" >&2
        exit 1
    fi
    printf '%s  ./bin/%s\n' "${line%% *}" "$bin"
done)

if [ "${1:-}" = "--check" ]; then
    if ! diff -u checksums - <<< "$expected"; then
        echo "checksums is out of date for gvisor-tap-vsock $VERSION, run ./update-checksums.sh" >&2
        exit 1
    fi
    echo "checksums match gvisor-tap-vsock $VERSION"
else
    printf '%s\n' "$expected" > checksums
    echo "checksums updated for gvisor-tap-vsock $VERSION"
fi
