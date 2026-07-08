{
  imports = [
    ./git.nix
    ./ghostty.nix
    ./packages.nix
    ./shell.nix
    ./ssh.nix
  ];

  home.stateVersion = "25.11";
  home.enableNixpkgsReleaseCheck = false;
  # XDG has no OS-level precedent on macOS (Apple uses ~/Library); exporting the
  # XDG_* vars only flips half-XDG CLIs (e.g. the `devx codex` wrapper) onto the
  # wrong code path. Keep them unexported and use classic $HOME dotfile locations.
  xdg.enable = false;
  programs.home-manager.enable = true;

  programs.gh.enable = true;
  programs.jq.enable = true;
  programs.nix-index-database.comma.enable = true;
  programs.ripgrep.enable = true;
}
