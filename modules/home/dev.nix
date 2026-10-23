# Language toolchains. They add about 3.5 GiB, so the server host does not import this module.
{ config, pkgs, ... }:

let
  home = config.home.homeDirectory;
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
    devenv
    gcloud
    nodejs_26
    python314
    ruby_4_0
    rust-bin.stable.latest.default
  ];

  programs.pnpm = {
    enable = true;
    # Keep the existing pnpm store and global programs in this directory.
    pnpmHome = "${home}/.local/share/pnpm";
  };

  programs.go = {
    enable = true;
    # nixpkgs' default go is the previous major. Track the current one.
    package = pkgs.go_1_27;
    env.GOPATH = home;
  };
}
