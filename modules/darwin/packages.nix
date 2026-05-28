{ pkgs, user, ... }:

let
  nixGuiApplications = [ ];

  homebrewGuiCasks = [
    "1password"
    "appcleaner"
    "ghostty"
    "rectangle"
    "tuple"
    "visual-studio-code"
  ];

  # Add Homebrew CLI tools here only when they are unavailable or unusable from
  # nixpkgs.
  homebrewBinaryCasks = [ ];
  homebrewFormulae = [
    "jolt"
  ];
  homebrewTaps = [
    "jordond/tap"
  ];
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
      autoUpdate = true;
      cleanup = "none";
      upgrade = true;
    };
  };
}
