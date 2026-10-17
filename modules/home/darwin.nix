{
  config,
  lib,
  options,
  pkgs,
  user,
  ...
}:

let
  home = config.home.homeDirectory;
  # Home Manager writes programs.git to ~/.config/git/config.
  # Git reads this path without XDG_CONFIG_HOME.
  managed = "${home}/.config/git/config";
  shim = "${home}/.config/git/config.local";
in
{
  imports = [
    ./ghostty.nix
    ./packages.nix
    ./ssh.nix
  ];

  # macOS uses ~/Library for application data.
  # XDG variables cause the devx codex wrapper to use incorrect paths.
  # Leave XDG variables unset. Use the standard dotfile paths in $HOME.
  xdg.enable = false;

  programs.nix-index-database.comma.enable = true;

  # The Home Manager configuration links to a read-only Nix store file.
  # Shopify dev and git maintenance register must write to the global configuration.
  # Use a writable file that includes the Home Manager configuration.
  # Keep runtime changes in that writable file.
  home.sessionVariables.GIT_CONFIG_GLOBAL = shim;

  home.activation.gitWritableGlobalConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e ${lib.escapeShellArg shim} ]; then
      verboseEcho "Git: Create writable global configuration ${shim}. Include the Home Manager configuration."
      mkdir -p ${lib.escapeShellArg (builtins.dirOf shim)}
      printf '[include]\n\tpath = %s\n' ${lib.escapeShellArg managed} > ${lib.escapeShellArg shim}
    fi
  '';

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

  programs.pnpm = {
    enable = true;
    # Keep the existing pnpm store and global programs in this directory.
    pnpmHome = "${home}/.local/share/pnpm";
  };

  programs.go = {
    enable = true;
    env.GOPATH = home;
  };

  programs.try = {
    enable = true;
    # try init uses the script without its wrapper.
    # Its env ruby shebang selects Tec Ruby, which loads old user gems.
    # Select the pinned Ruby interpreter and disable user gems.
    package = options.programs.try.package.default.overrideAttrs {
      postFixup = ''
        substituteInPlace $out/bin/.try-wrapped \
          --replace-fail '#!/usr/bin/env ruby' '#!${pkgs.ruby}/bin/ruby --disable-gems'
      '';
    };
  };

  programs.nh = {
    enable = true;
    flake = "${home}/src/github.com/epk/dotfiles";
  };

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
