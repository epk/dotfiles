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

    # Shopify dev adds dev/gitconfig to config.local. Do not add a second include for it here.
    # Commits in this public repository show their email. Use the GitHub noreply address.
    includes = [
      {
        condition = "gitdir:${config.programs.nh.flake}/";
        contents.user.email = "9075816+epk@users.noreply.github.com";
      }
    ];

    settings.user = { inherit (user) name email; };
  };

  programs.nh.flake = "${config.home.homeDirectory}/src/github.com/epk/dotfiles";

  programs.zsh.initContent = ''
    reload!() {
      # Determinate Nix logs cause nom to stop. See nix-output-monitor issue 320.
      local metadata
      metadata=$(mktemp) || return
      {
        sudo ${pkgs.age}/bin/age -d -i /var/lib/agenix/identity \
          ${config.programs.nh.flake}/secrets/private/metadata.age > "$metadata" &&
          DOTFILES_PRIVATE_CONFIG="$metadata" nh darwin switch --hostname macos-${user.role} --no-nom "$@" -- --impure
      } always {
        rm -f "$metadata"
      } && exec ${pkgs.zsh}/bin/zsh
    }
  '';
}
