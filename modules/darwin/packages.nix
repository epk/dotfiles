{ pkgs, user, ... }:

{
  fonts.packages = [
    pkgs.nerd-fonts.jetbrains-mono
  ];

  nix-homebrew = {
    enable = true;
    autoMigrate = true;
    user = user.username;
  };

  homebrew = {
    enable = true;

    # Signed macOS apps where Homebrew is the pragmatic source. Reach for a
    # Homebrew formula or binary cask only when a tool is unavailable or
    # unusable from nixpkgs; everything else belongs in modules/home.
    casks = [
      "1password"
      "appcleaner"
      # The agent CLIs ship as casks and release faster than pinned nixpkgs.
      "claude-code"
      "codex"
      "ghostty"
      "rectangle"
      "visual-studio-code"
    ];

    caskArgs.appdir = "/Applications";

    onActivation = {
      # A Homebrew auto-update temporarily makes mas 7 report every installed
      # App Store app as missing, causing the activation to fail. Formulae and
      # casks are still upgraded below, and manual brew commands still update.
      autoUpdate = false;
      cleanup = "none";
      upgrade = true;
    };
  };
}
