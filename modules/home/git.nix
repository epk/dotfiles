{
  config,
  lib,
  user,
  ...
}:

let
  # home-manager always writes programs.git to ~/.config/git/config, and git
  # reads that path natively without XDG_CONFIG_HOME, so it lives there
  # regardless of this repo's non-XDG setup.
  managed = "${config.home.homeDirectory}/.config/git/config";
  shim = "${config.home.homeDirectory}/.config/git/config.local";
in
{
  # The home-manager-generated config is a read-only symlink into the Nix store.
  # Tools like Shopify `dev` and `git maintenance register` write to the *global*
  # config (e.g. maintenance.repo) and fail with "could not lock config file ...
  # Permission denied". Point the global config at a writable shim that includes
  # the store one: declarative settings stay in Nix, the shim only captures keys
  # written at runtime.
  home.sessionVariables.GIT_CONFIG_GLOBAL = shim;

  home.activation.gitWritableGlobalConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e ${lib.escapeShellArg shim} ]; then
      verboseEcho "git: creating writable global config ${shim} (includes the home-manager config)"
      $DRY_RUN_CMD mkdir -p ${lib.escapeShellArg (builtins.dirOf shim)}
      $DRY_RUN_CMD printf '[include]\n\tpath = %s\n' ${lib.escapeShellArg managed} > ${lib.escapeShellArg shim}
    fi
  '';

  # home-manager asserts that at most one git diff integration is enabled, and
  # difftastic holds it (below). diff-so-fancy is therefore installed as a plain
  # binary and wired up by hand in the `gdd` alias in modules/home/shell.nix;
  # setting `enableGitIntegration` here would fail the assertion.
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
    # dev/gitconfig is intentionally NOT included here: Shopify `dev` adds its
    # own `include.path` for it to the writable global (config.local), so
    # declaring it again would double-include the same file.
    signing = {
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE/Cr+bIMxMzkk8dN7xxRsaJeHRifwlyTuh/ja9Uy9MN";
      format = "ssh";
      signer = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
      signByDefault = true;
    };

    settings = {
      user = { inherit (user) name email; };
      push.autoSetupRemote = true;
      fetch.prune = true;
      merge.conflictstyle = "zdiff3";
      pull.rebase = true;
    };
  };
}
