{ pkgs, ... }:

{
  home.packages = with pkgs; [
    curlFull
    dnsutils
    grpcurl
    hurl
    iperf3
    kubectl
    mtr
    nano
    nixfmt
    nmap
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
