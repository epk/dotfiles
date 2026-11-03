# zsh and the shared Home Manager configuration for one account. The server and the workshop guest import it.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  user = config.dotfiles.homeUser;
in
{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  options.dotfiles.homeUser = lib.mkOption {
    type = lib.types.str;
    default = (import ../../lib/user.nix).username;
    description = "Account that gets zsh and the shared Home Manager configuration.";
  };

  config = {
    programs.zsh = {
      enable = true;
      # Home Manager runs compinit from ~/.zshrc.
      enableGlobalCompInit = false;
    };
    users.users.${user}.shell = pkgs.zsh;
    # SSH sessions from Ghostty need its terminal description.
    environment.systemPackages = [ pkgs.ghostty.terminfo ];
    home-manager = (import ../../lib/hm.nix inputs) // {
      users.${user}.imports = [ ../home ];
    };
  };
}
