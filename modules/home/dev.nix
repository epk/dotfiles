# Language toolchains. The Macs and the workshop guest import it. The server host does not, because it adds about 3.5 GiB.
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
    nodejs_latest
    python315
    ruby_4_0
    rust-bin.stable.latest.default
  ];

  programs.uv.enable = true;

  programs.pnpm = {
    enable = true;
    # Keep the existing pnpm store and global programs in this directory.
    pnpmHome = "${home}/.local/share/pnpm";
  };

  programs.go = {
    enable = true;
    package = pkgs.go_latest;
    env.GOPATH = home;
  };
}
