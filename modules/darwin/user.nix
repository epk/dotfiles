{
  nix-index-database,
  pkgs,
  try,
  user,
  ...
}:

{
  nixpkgs.hostPlatform = "aarch64-darwin";
  # Keep this allowlist tight. The only consumer today is `_1password-cli`
  # in modules/home/packages.nix.
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
  };

  system.stateVersion = 6;
}
