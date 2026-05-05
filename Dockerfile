FROM alpine:3.23 AS gvisor-tap-vsock

WORKDIR /app/bin

ARG GVISOR_TAP_VSOCK_VERSION=v0.8.7

RUN wget https://github.com/containers/gvisor-tap-vsock/releases/download/${GVISOR_TAP_VSOCK_VERSION}/gvproxy-windows.exe && \
    wget https://github.com/containers/gvisor-tap-vsock/releases/download/${GVISOR_TAP_VSOCK_VERSION}/gvforwarder && \
    chmod +x gvproxy-windows.exe gvforwarder

FROM alpine:3.23

RUN apk add --no-cache iproute2 iptables

WORKDIR /app

COPY --from=gvisor-tap-vsock /app/bin/gvforwarder wsl-gvforwarder
COPY --from=gvisor-tap-vsock /app/bin/gvproxy-windows.exe wsl-gvproxy.exe
COPY wsl-vpnkit wsl-vpnkit.service ./
COPY wsl.conf /etc/wsl.conf

ARG VERSION=v0.0.0

RUN ln -s /app/wsl-vpnkit /usr/bin/ && \
    printf 'wsl-vpnkit version: %s\nwsl-gvforwarder version: %s\n' \
      "$VERSION" "$(./wsl-gvforwarder --version)" > ./version.txt
