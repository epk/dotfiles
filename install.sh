#!/usr/bin/bash -i
set -ex

date
echo "Starting Gitpod install.sh..."

if [[ -n "${GITPOD_DOTFILES_SKIP}" ]]; then
  echo "Exiting Gitpod install.sh early..."
  exit
fi


main() {
  # TODO this ideally lz4 should come pre-installed on Gitpod
  sudo apt-get install lz4

  # Needed since Gitpod already has their own `direnv` version installed
  # See https://discourse.nixos.org/t/home-manager-conflict-after-nix-upgrade/16967
  nix-env --set-flag priority 4 direnv
  date

  NIX_RESULT_PATH=$(curl https://storage.googleapis.com/epk-gitpod-nix/result.closure.lz4 | lz4 -d  | nix-store --import | tail -1)
  date

  $NIX_RESULT_PATH/activate
  date
}

time main
