{ user, ... }:

{
  imports = [
    ../../modules/darwin
    ../../profiles/work/darwin.nix
  ];

  networking = {
    computerName = "adityas-shopitop";
    hostName = "adityas-shopitop";
    localHostName = "adityas-shopitop";
  };

  home-manager.users.${user.username}.imports = [ ../../profiles/work/home.nix ];
}
