{
  lib,
  pkgs,
  ...
}:
{
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
  documentation.nixos.enable = lib.mkDefault false;
  system.stateVersion = lib.mkDefault "26.05";
}
