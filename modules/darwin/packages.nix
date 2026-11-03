# Mac apps, fonts and Homebrew for both Macs. modules/darwin/default.nix imports it.
{
  lib,
  pkgs,
  user,
  ...
}:
{
  fonts.packages = [
    pkgs.nerd-fonts.jetbrains-mono
  ];

  # nix-darwin copies these applications to /Applications/Nix Apps. nixpkgs or Renovate supplies the updates.
  environment.systemPackages = [
    pkgs.appcleaner
    pkgs.claude-code
    pkgs.codex
    pkgs.rectangle
    pkgs.vscode
  ];

  # The desktop integration requires the CLI at /usr/local/bin/op.
  programs._1password.enable = true;

  nix-homebrew = {
    enable = true;
    user = user.username;
    package = import ../../packages/homebrew { inherit lib; };
  };

  homebrew = {
    enable = true;

    # 1Password must update itself. A newer app migrates the vault data, and an older read-only copy cannot open it.
    # A beta build migrated the vault data, so only this cask opens it. The app updates itself on the stable channel.
    # Without greedy, brew upgrade does not replace it with a newer beta.
    casks = [
      {
        name = "1password@beta";
        greedy = false;
      }
    ];
    # Casks that update themselves are skipped by brew upgrade without greedy mode.
    greedyCasks = true;

    onActivation = {
      # Homebrew auto-update causes mas 7 to report installed applications as absent.
      # This error stops activation. Continue formula and cask upgrades.
      # Manual brew commands can update Homebrew.
      autoUpdate = false;
      upgrade = true;
    };
  };
}
