FROM alpine:3.23

ARG GVISOR_TAP_VSOCK_VERSION=v0.8.9

RUN apk add --no-cache iproute2 iptables

WORKDIR /app

RUN wget https://github.com/containers/gvisor-tap-vsock/releases/download/${GVISOR_TAP_VSOCK_VERSION}/gvproxy-windows.exe && \
    wget https://github.com/containers/gvisor-tap-vsock/releases/download/${GVISOR_TAP_VSOCK_VERSION}/gvforwarder && \
    chmod +x gvproxy-windows.exe gvforwarder

COPY wsl-vpnkit wsl-vpnkit.service ./
COPY wsl.conf /etc/wsl.conf

ARG VERSION=v0.0.0

RUN ln -s /app/wsl-vpnkit /usr/bin/ && \
    printf 'wsl-vpnkit version %s\n%s\n' \
      "$VERSION" "$(./gvforwarder --version)" > ./version.txt
