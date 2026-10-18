# Mac-only parts: GUI applications and macOS paths.
{
  config,
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

  programs.git = {
    signing = {
      key = user.signingPublicKey;
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
      nh darwin switch --hostname macos-${user.role} --no-nom "$@" && exec ${pkgs.zsh}/bin/zsh
    }
  '';
}
