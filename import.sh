#!/usr/bin/env bash 

set -euox pipefail

CMDSHELL="$(command -v cmd.exe || echo '/mnt/c/Windows/system32/cmd.exe')"
LOCALAPPDATA="$($CMDSHELL /d /v:off /c 'echo | set /p t=%LOCALAPPDATA%' 2>/dev/null)"
DUMP=wsl-vpnkit.tar.gz

# build if necessary
[ -f ${DUMP} ] || ./build.sh

# reinstall
wsl.exe --unregister wsl-vpnkit || :
wsl.exe --import wsl-vpnkit --version 2 "${LOCALAPPDATA}\\wsl\\wsl-vpnkit" ${DUMP}
