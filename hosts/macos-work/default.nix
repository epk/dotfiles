# The work Mac: its name, work apps and garbage collection. flake.nix builds it as macos-work.
{ pkgs, user, ... }:

{
  imports = [ ../../modules/darwin ];

  networking = {
    computerName = "adityas-shopitop";
    hostName = "adityas-shopitop";
    localHostName = "adityas-shopitop";
  };

  environment.systemPackages = [ pkgs.tuple ];
  # Nix updates Tuple, so turn off its own Sparkle updater.
  system.defaults.CustomUserPreferences."app.tuple.app" = {
    SUEnableAutomaticChecks = false;
    SUAutomaticallyUpdate = false;
  };

  # The Shopify Determinate Nixd configuration disables its garbage collector.
  launchd.daemons.nix-gc = {
    command = "/nix/var/nix/profiles/default/bin/nix-collect-garbage";
    serviceConfig.StartCalendarInterval = [
      {
        Weekday = 7;
        Hour = 3;
        Minute = 15;
      }
    ];
  };

  home-manager.users.${user.username}.imports = [ ./home.nix ];
}
