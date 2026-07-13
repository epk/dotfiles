{
  config,
  lib,
  user,
  ...
}:

{
  # The home-manager-generated git config (~/.config/git/config) is a read-only
  # symlink into the Nix store. Tools like Shopify `dev` and `git maintenance
  # register` need to write to the *global* config (e.g. maintenance.repo), which
  # fails with "could not lock config file ... Permission denied".
  #
  # Redirect the global config to a writable shim that simply includes the
  # read-only home-manager config. Declarative settings still live in the Nix
  # config; the shim only captures runtime-written keys.
  # home-manager's programs.git always writes to ~/.config/git/config, and git
  # reads that path natively without needing XDG_CONFIG_HOME exported, so the
  # config lives there regardless of our non-XDG setup.
  home.sessionVariables.GIT_CONFIG_GLOBAL = "${config.home.homeDirectory}/.config/git/config.local";

  home.activation.gitWritableGlobalConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    shim="${config.home.homeDirectory}/.config/git/config.local"
    if [ ! -e "$shim" ]; then
      verboseEcho "git: creating writable global config $shim (includes the home-manager config)"
      $DRY_RUN_CMD mkdir -p "$(dirname "$shim")"
      $DRY_RUN_CMD printf '[include]\n\tpath = %s\n' "${config.home.homeDirectory}/.config/git/config" > "$shim"
    fi
  '';

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
      user = {
        name = user.name;
        email = user.email;
      };

      push.autoSetupRemote = true;

      fetch.prune = true;

      merge.conflictstyle = "zdiff3";

      pull.rebase = true;
    };
  };
}
