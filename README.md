# wsl-vpnkit

This repository is based on the upstream [`sakai135/wsl-vpnkit`](https://github.com/sakai135/wsl-vpnkit) project. Release artifacts in this fork keep the upstream `gvisor-tap-vsock` executable names: `gvforwarder` and `gvproxy-windows.exe`.

`wsl-vpnkit` provides network connectivity to WSL 2 when a Windows VPN blocks access. It does not require Windows settings changes or administrator privileges on the Windows host.

## Setup

Before installing `wsl-vpnkit`, try `ping 1.2.3.4` inside WSL 2. If it succeeds, follow Microsoft's [WSL VPN troubleshooting](https://learn.microsoft.com/en-us/windows/wsl/troubleshooting#wsl-has-no-network-connectivity-once-connected-to-a-vpn) first. Mirrored networking and other [`.wslconfig` options](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#wslconfig) may also solve the problem.

### Install as a WSL distro

Download the versioned AMD64 `.wsl` asset and its checksum from the [latest release](https://github.com/yvh/wsl-vpnkit/releases/latest).

Verify the download before installing it:

```pwsh
# PowerShell
$VERSION = "v0.6.0" # Replace as needed; release tags include the leading "v"
$FILE = "wsl-vpnkit-$VERSION-amd64.wsl"

$EXPECTED = (Get-Content "$FILE.sha256").Split()[0].ToLower()
$ACTUAL = (Get-FileHash -Algorithm SHA256 $FILE).Hash.ToLower()
if ($ACTUAL -ne $EXPECTED) { throw "Checksum verification failed for $FILE" }
```

On WSL 2.4.4 or newer, install the distribution from PowerShell. Double-clicking the `.wsl` file is also supported.

```pwsh
wsl --install --from-file ".\$FILE"
```

Then run:

```sh
wsl.exe -d wsl-vpnkit --cd /app wsl-vpnkit
```

For an older WSL release, import it explicitly:

```pwsh
wsl --import wsl-vpnkit "$env:LOCALAPPDATA\wsl\wsl-vpnkit" ".\$FILE" --version 2
```

To update, download and verify the new asset as above, then replace the old distribution:

> [!WARNING]
> `wsl --unregister` permanently deletes the existing `wsl-vpnkit` distribution and all data stored inside it. The dedicated distribution is intended to be disposable; back up any custom files before continuing.

```pwsh
wsl --unregister wsl-vpnkit
wsl --install --from-file ".\$FILE"
```

### Install as a standalone script

The release distribution can also be unpacked into an existing WSL distro. This Ubuntu example installs all runtime dependencies and executables on `PATH`:

```sh
sudo apt-get update
sudo apt-get install iproute2 iptables dnsutils curl jq yq

VERSION="v0.6.0" # Replace as needed; release tags include the leading "v"
FILE="wsl-vpnkit-${VERSION}-amd64.wsl"

curl -fLO "https://github.com/yvh/wsl-vpnkit/releases/download/${VERSION}/${FILE}"
curl -fLO "https://github.com/yvh/wsl-vpnkit/releases/download/${VERSION}/${FILE}.sha256"
sha256sum -c "${FILE}.sha256"

tar --strip-components=1 -xf "$FILE" \
    app/wsl-vpnkit \
    app/wsl-vpnkit.yaml \
    app/gvproxy-windows.exe \
    app/gvforwarder \
    app/wsl-vpnkit.service

sudo install -m 0755 wsl-vpnkit gvforwarder gvproxy-windows.exe /usr/local/bin/
sudo install -m 0644 wsl-vpnkit.service /etc/systemd/system/
sudo wsl-vpnkit
```

### Set up systemd

WSL versions 0.67.6 and later [support systemd](https://learn.microsoft.com/en-us/windows/wsl/systemd). Enable it in the WSL distro where the service will run if it is not already active:

```ini
# /etc/wsl.conf
[boot]
systemd=true
```

Restart WSL from PowerShell after changing this setting:

```pwsh
wsl --shutdown
```

The supplied service uses a local `wsl-vpnkit` installation when available and otherwise invokes the dedicated `wsl-vpnkit` distro.

```sh
# Copy the service from the dedicated distro into the current distro
wsl.exe -d wsl-vpnkit --cd /app cat /app/wsl-vpnkit.service |
    sudo tee /etc/systemd/system/wsl-vpnkit.service

sudo systemctl enable --now wsl-vpnkit
systemctl status wsl-vpnkit
```

## Configuration

The supported environment variables are:

| Variable | Default | Description |
| --- | --- | --- |
| `DEBUG` | `0` | Enable shell tracing when set to a non-zero value. |
| `CHECK_HOST` | `host.containers.internal` | Host name used by startup DNS diagnostics. |
| `GVFORWARDER_PATH` | `gvforwarder` from `PATH` | Path to the Linux forwarder executable. |
| `GVPROXY_PATH` | `gvproxy-windows.exe` from `PATH` | Path to the Windows proxy executable. |
| `GVPROXY_CONFIG` | disabled | Path to a gvproxy YAML configuration file. |
| `PREEXISTING` | `1` | Create the TAP in the script when `1`; let gvforwarder create it with DHCP when `0`. |
| `WSL2_GATEWAY_IP` | auto-detected | Original WSL gateway restored during cleanup. |
| `WSL2_TAP_NAME` | auto-detected | Original WSL interface restored during cleanup. |
| `WSL2_RESOLVCONF` | `/mnt/wsl/resolv.conf`, then `/etc/resolv.conf` | Resolver file used to detect the original WSL gateway. |
| `TAP_NAME` | `wsltap` | VPN TAP interface name. |
| `TAP_MAC_ADDR` | `5a:94:ef:e4:0c:ee` | MAC address assigned to the VPN TAP interface. |
| `DHCP_TIMEOUT` | `30` | Maximum wait in seconds for a gvforwarder-owned DHCP lease. |
| `DHCP_POLL_INTERVAL` | `1` | Interval in seconds between DHCP lease checks. |
| `GVPROXY_SSH_PORT` | `-1` | SSH forwarding port passed to gvproxy; `-1` disables it. |
| `VPNKIT_GATEWAY_IP` | `192.168.127.1` | Gateway address for the vpnkit network. |
| `VPNKIT_HOST_IP` | `192.168.127.254` | Address used to reach the Windows host. |
| `VPNKIT_LOCAL_IP` | `192.168.127.2` | Address assigned to the WSL TAP interface. |
| `VPNKIT_SUBNET_MASK` | `24` | Prefix length of the vpnkit subnet. |

The repository includes [`wsl-vpnkit.yaml`](wsl-vpnkit.yaml) as a gvproxy configuration example. It can customize the subnet, gateway, virtual IPs, static lease and port forwarding. Network values from the YAML file override the corresponding `VPNKIT_*` and TAP defaults:

```sh
sudo GVPROXY_CONFIG=/path/to/wsl-vpnkit.yaml PREEXISTING=0 wsl-vpnkit
```

## Build and test

A local build on an AMD64 host produces `./wsl-vpnkit.wsl`. This project only supports AMD64; other architectures are not supported.

```sh
./build.sh

# Build with Podman
DOCKER=podman ./build.sh
```

Import the local build from WSL:

> [!WARNING]
> `./import.sh` always unregisters and replaces any existing distribution named `wsl-vpnkit`, deleting all data stored inside it.

```sh
./import.sh
```

Run the Docker test harness with:

```sh
./tests/run.sh
```

The tests exercise startup, cleanup, route and NAT restoration, diagnostics, DHCP mode, configuration parsing, invalid inputs and executable paths containing spaces.

A pushed `v*` tag builds a versioned AMD64 `.wsl` asset. The release workflow publishes its SHA-256 file and a build-provenance attestation for the `.wsl` asset.

## Troubleshooting

### `resolv.conf has been modified without setting generateResolvConf`

`wsl-vpnkit` normally detects the original gateway from the default route and falls back to `/mnt/wsl/resolv.conf` or `/etc/resolv.conf`. When using a custom resolver configuration, set `WSL2_GATEWAY_IP` explicitly if automatic detection is not possible.

### `gvproxy-windows.exe is not executable`

The distro must have [WSL interoperability](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#interop-settings) enabled. Security policies may only permit Windows executables from specific locations; copy `gvproxy-windows.exe` to an allowed location and set `GVPROXY_PATH`.

If `/usr/lib/binfmt.d/WSLInterop.conf` is missing, recreate the WSL interop registration and restart `systemd-binfmt`:

```sh
sudo sh -c 'echo :WSLInterop:M::MZ::/init:PF > /usr/lib/binfmt.d/WSLInterop.conf'
sudo systemctl restart systemd-binfmt
```

### Reset networking state

```pwsh
wsl --shutdown
kill -Name gvproxy-windows
```

Run `DEBUG=1 wsl-vpnkit` to include shell tracing in diagnostic output.

## Notes

- ICMP is not forwarded outside the gvisor network, so failed external pings are not a reliable health check.
- Ports on the WSL 2 VM are accessible from Windows through `localhost`.
- Ports on Windows are accessible from WSL through `host.containers.internal` or `192.168.127.254`.
- Corporate proxies, DNS suffixes and root certificates may still require distro-specific configuration.
