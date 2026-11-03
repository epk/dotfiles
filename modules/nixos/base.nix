# Shared settings for the server host and the workshop guest. Both import it.
{ pkgs, ... }:
let
  caches = import ../../lib/cachix.nix;
in
{
  # Determinate Nix supplies the nix path, so channels are unused.
  nix.channel.enable = false;
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
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  security.sudo.wheelNeedsPassword = false;
  time.timeZone = "UTC";
  documentation.nixos.enable = false;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  system.stateVersion = "26.11";
}
