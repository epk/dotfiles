{
  imports = [
    ./ghostty.nix
    ./git.nix
    ./packages.nix
    ./shell.nix
    ./ssh.nix
  ];

  home.stateVersion = "26.11";
  home.enableNixpkgsReleaseCheck = false;
  manual.manpages.enable = false;
  # macOS uses ~/Library for application data.
  # XDG variables cause the devx codex wrapper to use incorrect paths.
  # Leave XDG variables unset. Use the standard dotfile paths in $HOME.
  xdg.enable = false;

  programs.gh.enable = true;
  programs.jq.enable = true;
  programs.nix-index-database.comma.enable = true;
  programs.ripgrep.enable = true;
}
