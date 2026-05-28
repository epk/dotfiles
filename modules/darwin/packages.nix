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

  # Keep Homebrew CLI installation visibly empty. Add here only for tools that
  # are unavailable or unusable from nixpkgs.
  homebrewBinaryCasks = [ ];
  homebrewFormulae = [ ];
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
