{ pkgs, ... }:

{
  programs.zsh.enable = true;

  environment.shells = [
    pkgs.zsh
  ];

  nix.extraOptions = ''
    !include nix.conf.d/shopify.conf
  '';
}
