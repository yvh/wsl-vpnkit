ARG ALPINE_VERSION=3.24
ARG GVISOR_TAP_VSOCK_VERSION=v0.8.9

FROM alpine:${ALPINE_VERSION} AS gvisor-tap-vsock
ARG GVISOR_TAP_VSOCK_VERSION
WORKDIR /app/bin
RUN wget "https://github.com/containers/gvisor-tap-vsock/releases/download/${GVISOR_TAP_VSOCK_VERSION}/gvproxy-windows.exe" && \
    wget "https://github.com/containers/gvisor-tap-vsock/releases/download/${GVISOR_TAP_VSOCK_VERSION}/gvforwarder" && \
    chmod +x ./gvproxy-windows.exe ./gvforwarder
WORKDIR /app
COPY checksums ./
RUN sha256sum -c checksums

FROM alpine:${ALPINE_VERSION}
RUN apk update && \
    apk upgrade && \
    apk add --no-cache iproute2 iptables jq yq && \
    rm -rf /var/cache/apk/*

WORKDIR /app
COPY --from=gvisor-tap-vsock /app/bin/gvproxy-windows.exe ./
COPY --from=gvisor-tap-vsock /app/bin/gvforwarder ./
COPY wsl-vpnkit wsl-vpnkit.yaml wsl-vpnkit.service ./
COPY wsl.conf wsl-distribution.conf wsl-oobe.sh /etc/

ARG REF=https://example.com/
ARG VERSION=v0.0.0

RUN ln -s /app/wsl-vpnkit /app/gvforwarder /app/gvproxy-windows.exe /usr/local/bin/ && \
    echo "$REF" > ./ref && \
    echo "$VERSION" > ./version && \
    echo "amd64" > ./arch && \
    printf 'wsl-vpnkit version %s (%s)\n%s\n' \
        "$VERSION" "amd64" "$(./gvforwarder --version)" > ./version.txt
