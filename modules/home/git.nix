{
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
    settings = {
      push.autoSetupRemote = true;
      fetch.prune = true;
      merge.conflictstyle = "zdiff3";
      pull.rebase = true;
    };
  };
}
