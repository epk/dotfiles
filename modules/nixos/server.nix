# The server host: Tailscale, the administrator account, Nix and disk settings. hosts/server/default.nix imports it.
{
  config,
  inputs,
  pkgs,
  ...
}:
{
  imports = [ ./base.nix ];
  services.tailscale = {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "server";
  };
  users.users.${config.dotfiles.homeUser} = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ (import ../../lib/user.nix).sshPublicKey ];
  };

  environment.systemPackages = with pkgs; [
    gitMinimal
    jq
    ripgrep
    tmux
    curl
    netcat-openbsd
  ];
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.settings = {
    max-jobs = 1;
    cores = 2;
  };
  # Determinate Nixd collects unreferenced paths. It does not delete old generations.
  # The current system references every guest closure. Old generations are the rollback window.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  # microvm.nix enables KSM. Shared pages across guests leak memory timing between them.
  hardware.ksm.enable = false;
  services.fstrim.enable = true;
  services.journald.settings.Journal.SystemMaxUse = "256M";

  # Enable BBR congestion control and larger socket buffers for gigabit links.
  boot.kernelModules = [
    "tcp_bbr"
    "sch_fq"
  ];
  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
    "net.core.rmem_default" = 262144;
    "net.core.wmem_default" = 262144;
    "net.ipv4.tcp_rmem" = "4096 131072 16777216";
    "net.ipv4.tcp_wmem" = "4096 131072 16777216";
    "net.core.netdev_max_backlog" = 16384;
    "net.ipv4.tcp_mtu_probing" = 1;
    "net.ipv4.tcp_fastopen" = 3;
    "net.ipv4.tcp_slow_start_after_idle" = 0;
    "vm.swappiness" = 10;
  };
  # Spread single-queue NIC receive processing across all six CPU cores.
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="net", KERNEL=="eno1", ATTR{queues/rx-0/rps_cpus}="3f"
  '';
}
