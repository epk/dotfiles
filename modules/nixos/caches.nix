{ ... }:
let
  caches = import ../../lib/cachix.nix;
in
{
  # Shared substituters for the server host and the guest base.
  nix.settings = {
    substituters = [
      caches.epk.url
      caches.community.url
      caches.determinate.url
    ];
    trusted-public-keys = [
      caches.epk.publicKey
      caches.community.publicKey
      caches.determinate.publicKey
    ];
  };
}
