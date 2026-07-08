{ pkgs, ... }:

{
  # This machine runs Determinate Nix, whose own daemon manages the Nix
  # installation and /etc/nix/nix.conf. nix-darwin refuses to activate while
  # Determinate is present unless it is told to keep its hands off Nix, so we
  # disable nix-darwin's Nix management entirely.
  #
  # Consequence: the `nix.*` options (gc, optimise, settings, extraOptions,
  # envVars) are unavailable here. Nix configuration is owned by Determinate
  # plus the tec janitor, which writes /etc/nix/nix.custom.conf ->
  # nix.conf.d/shopify.conf. Anything Shopify-specific (trusted-users, the AWS
  # credentials path, GC) belongs in that chain, not in nix-darwin.
  nix.enable = false;

  programs.zsh.enable = true;

  environment.shells = [
    pkgs.zsh
  ];
}
