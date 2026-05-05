#!/usr/bin/env bash

set -euox pipefail

: "${DOCKER:=docker}"   # docker/podman command  (default: docker)
DUMP=wsl-vpnkit.tar.gz  # exported rootfs file
TAG_NAME=wsl-vpnkit      # build tag

# build
build_args=()
for var in http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY; do
    if [ -n "${!var:-}" ]; then
        build_args+=(--build-arg "$var=${!var}")
    fi
done
${DOCKER} build "${build_args[@]}" --tag ${TAG_NAME} .
CONTAINER_ID=$(${DOCKER} create ${TAG_NAME})
${DOCKER} export "${CONTAINER_ID}" | gzip > ${DUMP}
${DOCKER} container rm "${CONTAINER_ID}"
ls -la ${DUMP}
