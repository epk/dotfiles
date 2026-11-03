{
  lib,
  pkgs,
  user,
  ...
}:
let
  release = lib.importJSON ../../packages/homebrew-release.json;
  source = builtins.fetchGit {
    url = "https://github.com/Homebrew/brew";
    ref = "refs/tags/${release.version}";
    rev = release.rev;
    shallow = true;
  };
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

  # The module copies the application to /Applications/1Password.app, the path of op-ssh-sign.
  # It also puts the CLI at /usr/local/bin/op, which the desktop integration requires.
  programs._1password.enable = true;
  programs._1password-gui.enable = true;

  nix-homebrew = {
    enable = true;
    user = user.username;
    # Renovate updates the release and commit together. Nix fetches that exact commit.
    package = source // {
      name = "brew-${release.version}";
      version = release.version;
    };
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
