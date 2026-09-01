{
  host,
  lib,
  pkgs,
  ...
}:

{
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Keep this allowlist tight. The only consumer today is `_1password-cli`
  # in modules/home/packages.nix.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "1password-cli"
    ];

  # These workstations run Determinate Nix, whose own daemon manages the Nix
  # installation and /etc/nix/nix.conf. nix-darwin must keep its hands off Nix
  # when Determinate is present, so disable nix-darwin's Nix management.
  #
  # Consequence: the `nix.*` options (gc, optimise, settings, extraOptions,
  # envVars) are unavailable here. Nix configuration belongs to Determinate's
  # /etc/nix/nix.custom.conf chain, not nix-darwin.
  nix.enable = false;

  # Option manual generation drops the nixpkgs source string context, producing
  # an unreliable options.json and a Nix warning on every rebuild.
  documentation.enable = false;

  networking = {
    inherit (host) computerName hostName localHostName;
  };

  programs.zsh.enable = true;

  environment.shells = [
    pkgs.zsh
  ];

  system.stateVersion = 7;
}
