{ determinate, ... }:

let
  caches = import ../../lib/cachix.nix;
in
{
  # The module owns /etc/nix/nix.custom.conf. The work Mac keeps the Shopify file there.
  imports = [
    ../../modules/darwin
    determinate.darwinModules.default
  ];

  networking = {
    computerName = "Aditya’s MacBook Pro";
    hostName = "Adityas-MacBook-Pro";
    localHostName = "Adityas-MacBook-Pro";
  };

  determinateNix.determinateNixd.garbageCollector.strategy = "automatic";

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

  launchd.daemons.determinate-nix-upgrade = {
    command = "/usr/local/bin/determinate-nixd upgrade";
    serviceConfig = {
      StartCalendarInterval = [
        {
          Weekday = 7;
          Hour = 2;
          Minute = 45;
        }
      ];
      ProcessType = "Background";
      LowPriorityIO = true;
    };
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
