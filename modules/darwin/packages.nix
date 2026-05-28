{ pkgs, user, ... }:

let
  gcloud = pkgs.google-cloud-sdk.withExtraComponents (
    with pkgs.google-cloud-sdk.components;
    [
      alpha
      beta
      gke-gcloud-auth-plugin
    ]
  );

  nixTerminalBinaries = with pkgs; [
    _1password-cli
    gcloud
    kubectl
    nano
    nodejs_24
    pnpm
    tenv
  ];

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

  home-manager.users.${user.username}.home.packages = nixTerminalBinaries;

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
      cleanup = "uninstall";
      upgrade = true;
    };
  };
}
