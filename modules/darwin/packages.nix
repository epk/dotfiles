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

  # The module copies the application to /Applications/1Password.app, the path of op-ssh-sign.
  # It also puts the CLI at /usr/local/bin/op, which the desktop integration requires.
  programs._1password.enable = true;
  programs._1password-gui.enable = true;

  nix-homebrew = {
    enable = true;
    user = user.username;
    package = import ../../packages/homebrew { inherit lib; };
  };

  homebrew = {
    enable = true;

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
