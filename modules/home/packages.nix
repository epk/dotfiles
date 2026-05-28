{ pkgs, ... }:

let
  gcloud = pkgs.google-cloud-sdk.withExtraComponents (
    with pkgs.google-cloud-sdk.components;
    [
      alpha
      beta
      gke-gcloud-auth-plugin
    ]
  );
in
{
  home.packages = with pkgs; [
    _1password-cli
    gcloud
    kubectl
    nano
    nixfmt
    nodejs_24
    pnpm
    stern
    tenv
    watch
    wget
  ];
}
