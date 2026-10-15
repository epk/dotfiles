{
  nix-index-database,
  pkgs,
  try,
  user,
  ...
}:

{
  users.users.${user.username} = {
    home = "/Users/${user.username}";
    uid = 501;
    shell = pkgs.zsh;
  };
  users.knownUsers = [
    user.username
  ];

  system.primaryUser = user.username;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "before-nix";
    extraSpecialArgs = {
      inherit user;
    };
    sharedModules = [
      nix-index-database.homeModules.default
      try.homeModules.default
    ];
    # Each host adds its Home Manager profile to this list.
    users.${user.username}.imports = [ ../home ];
  };
}
