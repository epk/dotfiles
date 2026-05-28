{ lib, pkgs, ... }:

let
  # Canonical content tec janitor used to write into /etc/nix/nix.custom.conf.
  # nix.extraOptions below now includes nix.conf.d/shopify.conf directly,
  # making nix.custom.conf redundant. The preActivation script removes the
  # file whenever it still matches this exact form; if tec ever changes
  # what it writes, cmp will fail and the file will be left alone.
  tecCanonicalConfContent = pkgs.writeText "tec-nix-custom.conf" ''
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

  nix.gc = {
    automatic = true;
    interval = [
      {
        Weekday = 7;
        Hour = 3;
        Minute = 15;
      }
    ];
    options = "--delete-older-than 30d";
  };

  nix.optimise = {
    automatic = true;
    interval = [
      {
        Weekday = 7;
        Hour = 4;
        Minute = 15;
      }
    ];
  };

  nix.settings.trusted-users = lib.mkForce [
    "root"
    "@admin"
  ];

  nix.envVars = {
    # Shopify-specific: /etc/nix/aws/credentials is provisioned by tec.
    AWS_SHARED_CREDENTIALS_FILE = "/etc/nix/aws/credentials";
    OBJC_DISABLE_INITIALIZE_FORK_SAFETY = "YES";
  };

  system.activationScripts.preActivation.text = ''
    if [[ -f /etc/nix/nix.custom.conf ]] && cmp -s /etc/nix/nix.custom.conf ${tecCanonicalConfContent}; then
      rm /etc/nix/nix.custom.conf
    fi
  '';
}
