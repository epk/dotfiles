{ ... }:
let
  caches = import ../../lib/cachix.nix;
in
{
  # Shared Nix settings for the server host and the guest base.
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
}
