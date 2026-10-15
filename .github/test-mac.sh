#!/usr/bin/env bash
# Run setup.sh, reload! and the deployed reload! for one Mac on a macOS runner.
# A throwaway key and the example metadata replace the private values. Activation does not run.
set -euo pipefail
[ -n "${CI:-}" ] || {
  echo "Run this only in CI. It changes secrets/ in the checkout." >&2
  exit 1
}
host=$1
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)

home() {
  nix eval --raw "$1#darwinConfigurations.$host.config.home-manager.users" \
    --apply "u: (builtins.head (builtins.attrValues u)).$2"
}

# Activation installs these names. Homebrew and the App Store must still know them.
names() {
  nix eval --raw ".#darwinConfigurations.$host.config.homebrew" --apply "h: toString $1"
}
for kind in cask formula; do
  attr=$([ $kind = cask ] && echo casks || echo brews)
  list=$(names "(map (x: x.name) h.$attr)")
  read -ra list <<<"$list"
  if [ ${#list[@]} -gt 0 ]; then
    brew info --json=v2 "--$kind" "${list[@]}" | jq -e 'all(.casks[], .formulae[]; .disabled | not)' >/dev/null
  fi
done
apps=$(names "(builtins.attrValues h.masApps)")
for id in $apps; do
  curl -fsS --retry 3 "https://itunes.apple.com/lookup?id=$id" | jq -e '.resultCount > 0' >/dev/null
done

# Give this Mac a throwaway key, as 1Password gives the real one.
ssh-keygen -q -t ed25519 -N '' -f "$tmp/key"
public=$(cut -d' ' -f1,2 "$tmp/key.pub")
sed -i '' "s|^  $host = \".*\";|  $host = \"$public\";|" secrets/recipients.nix
grep -qF "$public" secrets/recipients.nix
"$(nix build --no-link --print-out-paths .#age)/bin/age" -R "$tmp/key.pub" \
  -o secrets/private/metadata.age lib/example-metadata.json

# reload! decrypts the checkout at the flake path of the example user.
flake=$(home . programs.nh.flake)
sudo mkdir -p "$(dirname "$flake")"
sudo ln -sfn "$PWD" "$flake"

mkdir "$tmp/bin"
cat >"$tmp/bin/sudo" <<'EOF'
#!/bin/sh
case $1 in
  */activate) echo "CI does not activate $1." ;;
  *) exec /usr/bin/sudo "$@" ;;
esac
EOF
# reload! switches. Build instead, with the nh of the reload! under test.
cat >"$tmp/bin/nh" <<'EOF'
#!/usr/bin/env bash
[ "$1 $2" = "darwin switch" ] && set -- darwin build "${@:3}"
exec "$REAL_NH/bin/nh" "$@"
EOF
chmod +x "$tmp/bin/"*

pbcopy <"$tmp/key"
PATH="$tmp/bin:$PATH" ./setup.sh

run_reload() {
  local fn nh
  fn=$(home "$1" programs.zsh.initContent | sed -n '/^reload!() {/,/^}/p')
  [ -n "$fn" ] || {
    echo "$1 does not define reload!." >&2
    exit 1
  }
  nh=$(home "$1" programs.nh.package.outPath)
  # reload! calls programs by store path. Fetch them.
  grep -o '/nix/store/[^/ ]*' <<<"$fn"$'\n'"$nh" | sort -u | xargs nix build --no-link
  REAL_NH=$nh NH_FLAKE=$PWD PATH="$tmp/bin:$PATH" zsh -fc "$fn; reload!" </dev/null
}
run_reload .
# Each Mac runs the reload! that it already has. It must work with this revision.
deployed=$(nix eval github:epk/dotfiles#darwinConfigurations --apply "c: c ? $host")
if [ "$deployed" = true ]; then
  run_reload github:epk/dotfiles
fi
