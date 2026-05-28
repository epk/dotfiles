{ lib, pkgs, ... }:

let
  tecNixCustomConf = pkgs.writeText "tec-nix-custom.conf" ''
    # Shopify Nix configuration (managed by tec janitor).
    # This file is included from nix.conf. Settings here survive
    # determinate-nixd regeneration of nix.conf.
    !include nix.conf.d/shopify.conf
  '';
in

{
  programs.zsh.enable = true;

  environment.shells = [
    pkgs.zsh
  ];

  nix.extraOptions = ''
    !include nix.conf.d/shopify.conf
  '';

  nix.envVars = {
    AWS_SHARED_CREDENTIALS_FILE = "/etc/nix/aws/credentials";
    OBJC_DISABLE_INITIALIZE_FORK_SAFETY = "YES";
  };

  system.activationScripts.checks.text = lib.mkBefore ''
    if [[ -f /etc/nix/nix.custom.conf ]] && cmp -s /etc/nix/nix.custom.conf ${tecNixCustomConf}; then
      rm /etc/nix/nix.custom.conf
    fi
  '';
}
