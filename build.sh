#!/usr/bin/env bash

set -euo pipefail

: "${DOCKER:=docker}"             # docker/podman command (default: docker)
: "${VERSION:=$(git describe --tags --always --dirty)}"
DUMP=wsl-vpnkit.wsl               # exported WSL distribution
TAG_NAME=wsl-vpnkit               # build tag
CONTAINER_ID=

cleanup () {
    if [ -n "$CONTAINER_ID" ]; then
        "$DOCKER" container rm "$CONTAINER_ID" >/dev/null 2>&1 || :
    fi
}
trap cleanup EXIT

# build
build_args=()
for var in http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY; do
    if [ -n "${!var:-}" ]; then
        build_args+=(--build-arg "$var=${!var}")
    fi
done
"$DOCKER" build "${build_args[@]}" \
    --build-arg "VERSION=$VERSION" \
    --tag "$TAG_NAME" .
CONTAINER_ID=$("$DOCKER" create "$TAG_NAME")
"$DOCKER" export "$CONTAINER_ID" | gzip > "$DUMP"
"$DOCKER" container rm "$CONTAINER_ID"
CONTAINER_ID=
ls -la "$DUMP"
