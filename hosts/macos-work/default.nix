{ user, ... }:

{
  imports = [ ../../modules/darwin ];

  networking = {
    computerName = "adityas-shopitop";
    hostName = "adityas-shopitop";
    localHostName = "adityas-shopitop";
  };

  homebrew.casks = [ "tuple" ];

  home-manager.users.${user.username}.imports = [ ./home.nix ];
}
