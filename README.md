# wsl-vpnkit

This repository is based on the upstream [`sakai135/wsl-vpnkit`](https://github.com/sakai135/wsl-vpnkit) project. Release artifacts in this fork keep the upstream `gvisor-tap-vsock` executable names: `gvforwarder` and `gvproxy-windows.exe`.

`wsl-vpnkit` provides network connectivity to WSL 2 when a Windows VPN blocks access. It does not require Windows settings changes or administrator privileges on the Windows host.

## Setup

Before installing `wsl-vpnkit`, try `ping 1.2.3.4` inside WSL 2. If it succeeds, follow Microsoft's [WSL VPN troubleshooting](https://learn.microsoft.com/en-us/windows/wsl/troubleshooting#wsl-has-no-network-connectivity-once-connected-to-a-vpn) first. Mirrored networking and other [`.wslconfig` options](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#wslconfig) may also solve the problem.

### Install as a WSL distro

Download the versioned AMD64 `.wsl` asset and its checksum from the [latest release](https://github.com/yvh/wsl-vpnkit/releases/latest).

Verify the download before opening it:

```pwsh
# PowerShell
$VERSION = "<version>"
$FILE = "wsl-vpnkit-$VERSION-amd64.wsl"

$EXPECTED = (Get-Content "$FILE.sha256").Split()[0].ToLower()
$ACTUAL = (Get-FileHash -Algorithm SHA256 $FILE).Hash.ToLower()
if ($ACTUAL -ne $EXPECTED) { throw "Checksum verification failed for $FILE" }
```

On WSL 2.4.4 or newer, open the `.wsl` file to install the distribution. Then run:

```sh
wsl.exe -d wsl-vpnkit --cd /app wsl-vpnkit
```

For an older WSL release, import it explicitly:

```pwsh
wsl --import wsl-vpnkit "$env:LOCALAPPDATA\wsl\wsl-vpnkit" .\wsl-vpnkit-<version>-amd64.wsl --version 2
```

To update, unregister the old distribution and install the new asset:

```pwsh
wsl --unregister wsl-vpnkit
```

### Install as a standalone script

The release distribution can also be unpacked into an existing WSL distro. This Ubuntu example installs all runtime dependencies and executables on `PATH`:

```sh
sudo apt-get update
sudo apt-get install iproute2 iptables dnsutils curl jq yq

VERSION="<version>"
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

WSL versions 0.67.6 and later [support systemd](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#systemd-support). The supplied service uses a local `wsl-vpnkit` installation when available and otherwise invokes the dedicated `wsl-vpnkit` distro.

```sh
# Copy the service from the dedicated distro into the current distro
wsl.exe -d wsl-vpnkit --cd /app cat /app/wsl-vpnkit.service |
    sudo tee /etc/systemd/system/wsl-vpnkit.service

sudo systemctl enable --now wsl-vpnkit
systemctl status wsl-vpnkit
```

## Configuration

The most commonly used environment variables are:

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
| `TAP_NAME` | `wsltap` | VPN TAP interface name. |
| `DHCP_TIMEOUT` | `30` | Maximum wait in seconds for a gvforwarder-owned DHCP lease. |

The repository includes [`wsl-vpnkit.yaml`](wsl-vpnkit.yaml) as a gvproxy configuration example. It can customize the subnet, gateway, virtual IPs, static lease and port forwarding:

```sh
sudo GVPROXY_CONFIG=/path/to/wsl-vpnkit.yaml PREEXISTING=0 wsl-vpnkit
```

## Build and test

A local build targets the host architecture and produces `./wsl-vpnkit.wsl`:

```sh
./build.sh

# Build with Podman
DOCKER=podman ./build.sh

# Import the local build
./import.sh
```

Run the Docker test harness with:

```sh
./tests/run.sh
```

The tests exercise startup, cleanup, route and NAT restoration, diagnostics, DHCP mode, configuration parsing, invalid inputs and executable paths containing spaces.

A pushed `v*` tag builds a versioned AMD64 `.wsl` asset. The release workflow publishes its SHA-256 file and build-provenance attestation and embeds SBOM/provenance data in the build.

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
