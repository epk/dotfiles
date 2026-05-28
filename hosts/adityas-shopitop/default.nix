{
  pkgs,
  try,
  user,
  ...
}:

{
  imports = [
    ../../modules/darwin
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "1password-cli"
    ];

  users.users.${user.username} = {
    home = "/Users/${user.username}";
    uid = 501;
    shell = pkgs.zsh;
  };
  users.knownUsers = [
    user.username
  ];

  system.primaryUser = user.username;
  networking = {
    computerName = user.computerName;
    hostName = user.computerName;
    localHostName = user.computerName;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "before-nix";
    extraSpecialArgs = {
      inherit user;
    };
    sharedModules = [
      try.homeModules.default
    ];
    users.${user.username} = import ../../modules/home;
  };

  system.stateVersion = 6;
}
