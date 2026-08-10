{ pkgs, user, ... }:

let
  nixGuiApplications = [ ];

  homebrewGuiCasks = [
    "1password"
    "appcleaner"
    "ghostty"
    "rectangle"
    "visual-studio-code"
  ];

  # Add Homebrew CLI tools here only when they are unavailable or unusable from
  # nixpkgs.
  homebrewBinaryCasks = [ ];
  homebrewFormulae = [ ];
  homebrewTaps = [ ];
in
{
  environment.systemPackages = nixGuiApplications;
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  nix-homebrew = {
    enable = true;
    autoMigrate = true;
    user = user.username;
  };

  homebrew = {
    enable = true;
    taps = homebrewTaps;
    brews = homebrewFormulae;
    casks = homebrewGuiCasks ++ homebrewBinaryCasks;
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
