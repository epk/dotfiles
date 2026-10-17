{
  imports = [
    ./git.nix
    ./shell.nix
  ];

  home.stateVersion = "26.11";
  home.enableNixpkgsReleaseCheck = false;
  manual.manpages.enable = false;

  programs.gh.enable = true;
  programs.jq.enable = true;
  programs.ripgrep.enable = true;
}
