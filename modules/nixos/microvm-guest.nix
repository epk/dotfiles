{
  lib,
  pkgs,
  ...
}:
let
  caches = import ../../lib/cachix.nix;
in
{
  nix.settings = {
    substituters = [
      caches.epk.url
      caches.community.url
    ];
    trusted-public-keys = [
      caches.epk.publicKey
      caches.community.publicKey
    ];
  };
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
  documentation.nixos.enable = lib.mkDefault false;
  system.stateVersion = lib.mkDefault "26.05";
}
