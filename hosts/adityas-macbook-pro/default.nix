{ user, ... }:

{
  imports = [
    ../../modules/darwin
    ../../profiles/personal/darwin.nix
  ];

  networking = {
    computerName = user.computerName;
    hostName = user.hostName;
    localHostName = user.localHostName;
  };

  home-manager.users.${user.username} = {
    imports = [
      ../../modules/home
    ];
  };
}
