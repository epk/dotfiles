{ pkgs, ... }:

{
  # These workstations run Determinate Nix, whose own daemon manages the Nix
  # installation and /etc/nix/nix.conf. nix-darwin must keep its hands off Nix
  # when Determinate is present, so disable nix-darwin's Nix management.
  #
  # Consequence: the `nix.*` options (gc, optimise, settings, extraOptions,
  # envVars) are unavailable here. Nix configuration belongs to Determinate's
  # /etc/nix/nix.custom.conf chain, not nix-darwin.
  nix.enable = false;

  programs.zsh.enable = true;

  environment.shells = [
    pkgs.zsh
  ];
}
