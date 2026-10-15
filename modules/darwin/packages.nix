{ pkgs, user, ... }:

{
  fonts.packages = [
    pkgs.nerd-fonts.jetbrains-mono
  ];

  nix-homebrew = {
    enable = true;
    user = user.username;
  };

  homebrew = {
    enable = true;

    casks = [
      "1password"
      "appcleaner"
      # Homebrew casks supply newer agent CLI versions.
      "claude-code@latest"
      "codex"
      "ghostty"
      "rectangle"
      "visual-studio-code"
    ];

    onActivation = {
      # Homebrew auto-update causes mas 7 to report installed applications as absent.
      # This error stops activation. Continue formula and cask upgrades.
      # Manual brew commands can update Homebrew.
      autoUpdate = false;
      upgrade = true;
    };
  };
}
