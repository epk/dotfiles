#!/bin/sh
# First setup of a Mac. After this, use reload!.
set -eu
cd "$(dirname "$0")"
host=macos-${1:?Usage: ./setup.sh personal|work}
system=$(nix build --no-link --print-out-paths ".#darwinConfigurations.$host.system")
sudo -H /nix/var/nix/profiles/default/bin/nix-env -p /nix/var/nix/profiles/system --set "$system"
sudo "$system/activate"
echo "Setup of $host is complete. Open a new shell. Then use reload!"
