#!/bin/sh
# First setup of a Mac. After this, use reload!.
set -eu
cd "$(dirname "$0")"
host=macos-${1:?Usage: ./setup.sh personal|work}
sudo -H /nix/var/nix/profiles/default/bin/nix run --inputs-from . nix-darwin#darwin-rebuild -- switch --flake ".#$host"
echo "Setup of $host is complete. Open a new shell. Then use reload!"
