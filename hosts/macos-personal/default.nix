# The personal Mac: its name, caches, upgrades and personal apps. flake.nix builds it as macos-personal.
{ inputs, pkgs, ... }:

let
  caches = import ../../lib/cachix.nix;
in
{
  # The module owns /etc/nix/nix.custom.conf. The work Mac keeps the Shopify file there.
  imports = [
    ../../modules/darwin
    inputs.determinate.darwinModules.default
  ];

  networking = {
    computerName = "Aditya’s MacBook Pro";
    hostName = "Adityas-MacBook-Pro";
    localHostName = "Adityas-MacBook-Pro";
  };

  determinateNix.customSettings = {
    extra-substituters = map (cache: cache.url) caches.mac;
    extra-trusted-public-keys = map (cache: cache.publicKey) caches.mac;
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

  environment.systemPackages = [ pkgs.slack ];
  # Nix updates Slack. Slack documents this key to turn off its own updater.
  system.defaults.CustomUserPreferences."com.tinyspeck.slackmacgap".SlackNoAutoUpdates = true;

  homebrew = {
    # The Network Extension requires the signed application in /Applications.
    casks = [ "tailscale-app" ];

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
