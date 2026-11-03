# Mac apps, fonts and Homebrew for both Macs. modules/darwin/default.nix imports it.
{
  lib,
  pkgs,
  user,
  ...
}:
let
  # 1Password 8.12.44-25.BETA migrated the vault data on the work Mac, and an older app cannot open it.
  # Nix installs 1Password when Renovate pins a stable release at this version or newer.
  nixOnePassword = lib.versionAtLeast pkgs._1password-gui.version "8.12.44";
in
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
  # The module copies the application to /Applications/1Password.app, the path of op-ssh-sign.
  programs._1password-gui.enable = nixOnePassword;

  nix-homebrew = {
    enable = true;
    user = user.username;
    package = import ../../packages/homebrew { inherit lib; };
  };

  homebrew = {
    enable = true;

    # Until then, only the beta cask opens the vault data. Without greedy, brew upgrade installs no newer beta.
    casks = lib.optional (!nixOnePassword) {
      name = "1password@beta";
      greedy = false;
    };
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
