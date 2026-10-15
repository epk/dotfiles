#!/bin/sh
# First setup of a Mac. Copy the agenix private key of this Mac from 1Password, then run this script.
# After this, use reload!.
set -eu
cd "$(dirname "$0")"
age=$(nix build --no-link --print-out-paths .#age)/bin/age
metadata=$(mktemp)
trap 'rm -f "$metadata"; pbcopy </dev/null' EXIT
key=$(pbpaste)

for host in $(nix eval --raw .#darwinConfigurations --apply 'c: toString (builtins.attrNames c)'); do
  echo | "$age" -r "$(nix eval --raw --file secrets/recipients.nix "$host")" -o "$metadata"
  printf '%s\n' "$key" | "$age" -d -i - "$metadata" >/dev/null 2>&1 && break
  host=
done
if [ -z "$host" ]; then
  echo 'The clipboard does not contain the agenix private key of a Mac.' >&2
  exit 1
fi

printf '%s\n' "$key" | "$age" -d -i - secrets/private/metadata.age >"$metadata"
system=$(DOTFILES_PRIVATE_CONFIG=$metadata nix build --impure --no-link --print-out-paths ".#darwinConfigurations.$host.system")
sudo install -d -m 0700 /var/lib/agenix
printf '%s\n' "$key" | sudo sh -c 'umask 077 && cat > /var/lib/agenix/identity'
sudo -H /nix/var/nix/profiles/default/bin/nix-env -p /nix/var/nix/profiles/system --set "$system"
sudo "$system/activate"
echo "Setup of $host is complete. Open a new shell. Then use reload!"
