{ user, ... }:

{
  imports = [ ../../modules/darwin ];

  networking = {
    computerName = "adityas-shopitop";
    hostName = "adityas-shopitop";
    localHostName = "adityas-shopitop";
  };

  homebrew.casks = [ "tuple" ];

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
