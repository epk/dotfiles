# Home Manager settings for the Macs only: Git signing, Ghostty, SSH and reload!. modules/darwin/default.nix imports it.
{
  config,
  lib,
  pkgs,
  user,
  ...
}:

{
  imports = [
    ./ghostty.nix
    ./ssh.nix
  ];

  # macOS uses ~/Library for application data.
  # XDG variables cause the devx codex wrapper to use incorrect paths.
  # Leave XDG variables unset. Use the standard dotfile paths in $HOME.
  xdg.enable = false;

  programs.git = {
    signing = {
      key = user.sshPublicKey;
      format = "ssh";
      signer = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
      signByDefault = true;
    };

    settings.user.name = user.name;
  };

  # Nix updates VS Code. Its settings.json has comments, so insert the key as text instead of a JSON rewrite.
  home.activation.vscodeUpdateMode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="${config.home.homeDirectory}/Library/Application Support/Code/User/settings.json"
    if [ ! -e "$settings" ]; then
      run mkdir -p "$(dirname "$settings")"
      run ${pkgs.bash}/bin/bash -c 'printf "{\n  \"update.mode\": \"none\"\n}\n" > "$1"' _ "$settings"
    elif ! ${pkgs.gnugrep}/bin/grep -q '"update.mode": *"none"' "$settings"; then
      if ${pkgs.gnugrep}/bin/grep -q '"update.mode"' "$settings"; then
        run ${pkgs.gnused}/bin/sed -i -E 's/("update\.mode": *)"[^"]*"/\1"none"/' "$settings"
      else
        run ${pkgs.gnused}/bin/sed -i '0,/{/s//{\n  "update.mode": "none",/' "$settings"
      fi
    fi
  '';

  programs.nh.flake = "${config.home.homeDirectory}/src/github.com/epk/dotfiles";

  programs.zsh.initContent = ''
    reload!() {
      # Determinate Nix logs cause nom to stop. See nix-output-monitor issue 320.
      # The new shell loads the session variables again only without these guards.
      nh darwin switch --hostname macos-${user.role} --no-nom "$@" &&
        unset __HM_SESS_VARS_SOURCED __HM_ZSH_SESS_VARS_SOURCED &&
        exec ${pkgs.zsh}/bin/zsh
    }
  '';
}
