{
  config,
  lib,
  user,
  ...
}:

let
  # Home Manager writes programs.git to ~/.config/git/config.
  # Git reads this path without XDG_CONFIG_HOME.
  managed = "${config.home.homeDirectory}/.config/git/config";
  shim = "${config.home.homeDirectory}/.config/git/config.local";
in
{
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

  # Home Manager permits one Git diff integration. Use difftastic for that integration.
  # Install diff-so-fancy as a separate program.
  # The gdd alias in modules/home/shell.nix selects diff-so-fancy.
  programs.diff-so-fancy.enable = true;

  programs.difftastic = {
    enable = true;
    git.enable = true;
  };

  programs.git = {
    enable = true;
    ignores = [
      ".DS_Store"
      "*.swp"
      "*.swo"
    ];
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

    settings = {
      user = { inherit (user) name email; };
      push.autoSetupRemote = true;
      fetch.prune = true;
      merge.conflictstyle = "zdiff3";
      pull.rebase = true;
    };
  };
}
