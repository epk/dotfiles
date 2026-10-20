{ determinate, ... }:
let
  caches = import ../../lib/cachix.nix;
in
{
  # The module owns /etc/nix/nix.custom.conf. The work Mac keeps the Shopify file there.
  imports = [ determinate.darwinModules.default ];
  determinateNix.customSettings = {
    extra-substituters = [
      caches.epk.url
      caches.devenv.url
    ];
    extra-trusted-public-keys = [
      caches.epk.publicKey
      caches.devenv.publicKey
    ];
  };

  homebrew = {
    # Homebrew Bundle requires mas to install masApps.
    # Homebrew supplies a newer uv version than the pinned nixpkgs input.
    brews = [
      "mas"
      "uv"
    ];

    casks = [
      "slack"
      "tailscale-app"
    ];

    masApps = {
      Infuse = 1136220934;
      Keynote = 361285480;
      Numbers = 361304891;
      Pages = 361309726;
      "Wipr 2" = 1662217862;
      WireGuard = 1451685025;
    };
  };
}
