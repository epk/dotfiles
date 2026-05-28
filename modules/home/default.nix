{
  imports = [
    ./git.nix
    ./ghostty.nix
    ./shell.nix
    ./ssh.nix
  ];

  home.stateVersion = "25.11";
  home.enableNixpkgsReleaseCheck = false;
  programs.home-manager.enable = true;

  programs.gh.enable = true;
  programs.ripgrep.enable = true;
}
