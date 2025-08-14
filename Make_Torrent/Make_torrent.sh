#!/bin/bash
# Simple wrapper to create a torrent file using ctorrent with a fixed tracker.
# Usage: ./Make_torrent.sh <path>

set -euo pipefail

# Ensure ctorrent is installed; install if missing (Debian 12 default)
if ! command -v ctorrent >/dev/null 2>&1; then
    echo "ctorrent not found, installing..."
    sudo apt-get update -y
    sudo apt-get install -y ctorrent
fi

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <path>"
    exit 1
fi

target="${1%/}"

if [[ ! -e "$target" ]]; then
    echo "Error: path '$target' does not exist" >&2
    exit 1
fi

ctorrent -t -p -u "https://tracker.m-team.cc/" -s "${target}.torrent" "$target"
