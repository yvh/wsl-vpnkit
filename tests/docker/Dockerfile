ARG GVISOR_TAP_VSOCK_VERSION=v0.8.9

FROM docker.io/library/golang:1.26.6 AS gvisor-tap-vsock
ARG GVISOR_TAP_VSOCK_VERSION
WORKDIR /app
RUN git clone --depth 1 --branch "${GVISOR_TAP_VSOCK_VERSION}" \
        https://github.com/containers/gvisor-tap-vsock.git . && \
    CGO_ENABLED=0 make gvproxy vm && \
    chmod +x ./bin/gvproxy ./bin/gvforwarder

FROM docker.io/library/alpine:3.24.1
RUN apk update && \
    apk upgrade && \
    apk add iproute2 iptables jq yq && \
    rm -rf /var/cache/apk/*
WORKDIR /app
COPY --from=gvisor-tap-vsock /app/bin/gvforwarder ./gvforwarder
COPY --from=gvisor-tap-vsock /app/bin/gvproxy ./gvproxy-windows.exe
COPY ./wsl-vpnkit ./wsl-vpnkit.service ./
COPY tests/docker/mock-vm tests/docker/test.sh /tests/
RUN ln -s /app/wsl-vpnkit /app/gvforwarder /app/gvproxy-windows.exe /usr/local/bin/

ENTRYPOINT ["/tests/test.sh"]
