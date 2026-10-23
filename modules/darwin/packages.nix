{ pkgs, user, ... }:
let
  release = builtins.fromJSON (builtins.readFile ../../packages/homebrew-release.json);
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
