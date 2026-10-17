{
  config,
  homeManager,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.workshop;
  state = "${config.microvm.stateDir}/workshop";
  disks = cfg.storageDirectory;
in
{
  imports = [ ./microvm-storage.nix ];
  options.services.workshop = {
    enable = lib.mkEnableOption "the persistent coding and browser guest";
    storageDirectory = lib.mkOption {
      type = lib.types.strMatching "/storage/(nvme|sata)/vms/workshop";
      default = "/storage/nvme/vms/workshop";
      description = "Directory for the private sparse guest disks.";
    };
    uplink = lib.mkOption {
      type = lib.types.str;
      default = "eno1";
      description = "Host interface for public guest IPv4 traffic.";
    };
    administratorKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Public SSH keys for the guest administrator.";
    };
  };
  config = lib.mkIf cfg.enable {
    microvm.vms.workshop = {
      # The guest evaluates its own nixpkgs, so its unfree and problem settings apply.
      pkgs = null;
      specialArgs = {
        workshop = cfg;
        inherit homeManager;
      };
      config = ./guests/workshop.nix;
    };
    systemd.services."microvm@workshop" = {
      requires = [ "workshop-network.service" ];
      after = [ "workshop-network.service" ];
      serviceConfig = {
        CPUQuota = "200%";
        CPUWeight = 50;
        MemoryMax = "5G";
        TasksMax = 2048;
        UMask = "0077";
        RuntimeDirectory = "workshop-jail";
        RootDirectory = "/run/workshop-jail";
        BindReadOnlyPaths = [ "/nix/store" ];
        BindPaths = [
          state
          disks
          "/dev/kvm"
          "/dev/net/tun"
        ];
        ReadWritePaths = [
          state
          disks
        ];
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        NoNewPrivileges = true;
        CapabilityBoundingSet = "";
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
        ];
        IPAddressDeny = "any";
        DevicePolicy = "closed";
        DeviceAllow = [
          "/dev/kvm rw"
          "/dev/net/tun rw"
        ];
        ExecStartPost = lib.mkForce [ "" ];
        ExecStopPost = lib.mkForce [ "" ];
      };
    };
    # The guest uses the host as its IPv4 router.
    boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = true;
    # Apply rules only to the guest interface. Keep host access rules unchanged.
    systemd.services.workshop-network = {
      description = "Private routed network for the agent VM";
      requires = [ "microvm-tap-interfaces@workshop.service" ];
      after = [
        "microvm-tap-interfaces@workshop.service"
        "firewall.service"
      ];
      before = [ "microvm@workshop.service" ];
      partOf = [
        "microvm@workshop.service"
        "firewall.service"
      ];
      path = [
        pkgs.iproute2
        pkgs.iptables
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -euo pipefail
        ip address replace 10.77.0.1/30 dev workshop-tap
        # Route guest traffic with the main table, before the Tailscale rules, so it cannot reach the tailnet.
        ip rule show | grep -q 'iif workshop-tap lookup main' ||
          ip rule add iif workshop-tap priority 5200 lookup main
        for chain in workshop-input workshop-forward workshop-return; do
          iptables -N "$chain" 2>/dev/null || true
          iptables -F "$chain"
        done
        iptables -A workshop-input ! -s 10.77.0.2/32 -j DROP
        iptables -A workshop-input -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        iptables -A workshop-input -j REJECT
        iptables -A workshop-forward ! -s 10.77.0.2/32 -j DROP
        iptables -A workshop-forward -m addrtype --dst-type LOCAL -j REJECT
        for network in 0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4; do
          iptables -A workshop-forward -d "$network" -j REJECT
        done
        iptables -A workshop-forward -o ${lib.escapeShellArg cfg.uplink} -j ACCEPT
        iptables -A workshop-forward -j REJECT
        iptables -A workshop-return -d 10.77.0.2/32 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        iptables -A workshop-return -j DROP
        iptables -C INPUT -i workshop-tap -j workshop-input 2>/dev/null || iptables -I INPUT -i workshop-tap -j workshop-input
        iptables -C FORWARD -i workshop-tap -j workshop-forward 2>/dev/null || iptables -I FORWARD -i workshop-tap -j workshop-forward
        iptables -C FORWARD -o workshop-tap -j workshop-return 2>/dev/null || iptables -I FORWARD -o workshop-tap -j workshop-return
        iptables -t nat -C POSTROUTING -s 10.77.0.2/32 -o ${lib.escapeShellArg cfg.uplink} -j MASQUERADE 2>/dev/null ||
          iptables -t nat -A POSTROUTING -s 10.77.0.2/32 -o ${lib.escapeShellArg cfg.uplink} -j MASQUERADE
        ip6tables -C INPUT -i workshop-tap -j DROP 2>/dev/null || ip6tables -I INPUT -i workshop-tap -j DROP
        ip6tables -C FORWARD -i workshop-tap -j DROP 2>/dev/null || ip6tables -I FORWARD -i workshop-tap -j DROP
        ip6tables -C FORWARD -o workshop-tap -j DROP 2>/dev/null || ip6tables -I FORWARD -o workshop-tap -j DROP
      '';
      preStop = ''
        ip rule del iif workshop-tap priority 5200 lookup main 2>/dev/null || true
        iptables -D INPUT -i workshop-tap -j workshop-input 2>/dev/null || true
        iptables -D FORWARD -i workshop-tap -j workshop-forward 2>/dev/null || true
        iptables -D FORWARD -o workshop-tap -j workshop-return 2>/dev/null || true
        iptables -t nat -D POSTROUTING -s 10.77.0.2/32 -o ${lib.escapeShellArg cfg.uplink} -j MASQUERADE 2>/dev/null || true
        ip6tables -D INPUT -i workshop-tap -j DROP 2>/dev/null || true
        ip6tables -D FORWARD -i workshop-tap -j DROP 2>/dev/null || true
        ip6tables -D FORWARD -o workshop-tap -j DROP 2>/dev/null || true
        for chain in workshop-input workshop-forward workshop-return; do
          iptables -F "$chain" 2>/dev/null || true
          iptables -X "$chain" 2>/dev/null || true
        done
      '';
    };
  };
}
