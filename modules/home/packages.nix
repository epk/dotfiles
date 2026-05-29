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
    curlFull
    dnsutils
    gcloud
    go
    grpcurl
    hurl
    iperf3
    kubectl
    mtr
    nano
    nixfmt
    nmap
    nodejs_24
    pnpm
    python314
    ruby_4_0
    rust-bin.stable.latest.default
    socat
    stern
    tcpdump
    tenv
    watch
    websocat
    wget
    whois
    xh
  ];
}
