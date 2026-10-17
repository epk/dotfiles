# zsh and the shared Home Manager configuration for one account.
{
  config,
  homeManager,
  lib,
  pkgs,
  ...
}:
let
  user = config.dotfiles.homeUser;
in
{
  imports = [ homeManager ];

  options.dotfiles.homeUser = lib.mkOption {
    type = lib.types.str;
    description = "Account that gets zsh and the shared Home Manager configuration.";
  };

  config = {
    programs.zsh = {
      enable = true;
      # Home Manager runs compinit from ~/.zshrc.
      enableGlobalCompInit = false;
    };
    users.users.${user}.shell = pkgs.zsh;
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "before-nix";
      users.${user}.imports = [ ../home ];
    };
  };
}
