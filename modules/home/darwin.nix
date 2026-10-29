# Mac-only parts: GUI applications and macOS paths.
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

  # The CLI signs in through the 1Password desktop application.
  home.packages = [ pkgs._1password-cli ];

  # Applications that launchd starts, such as bb, do not read the shell session variables.
  # The shell expands values that refer to other variables, such as TERMINFO_DIRS.
  launchd.agents.session-variables = {
    enable = true;
    config = {
      ProgramArguments = [
        "/bin/sh"
        "-c"
        ''
          . ${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh
          exec /bin/launchctl setenv ${
            lib.concatMapStringsSep " " (name: "${name} \"\$${name}\"") (
              lib.attrNames config.home.sessionVariables
            )
          }
        ''
      ];
      RunAtLoad = true;
    };
  };

  programs.git = {
    signing = {
      key = user.sshPublicKey;
      format = "ssh";
      signer = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
      signByDefault = true;
    };

    settings.user.name = user.name;
  };

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
