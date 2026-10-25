{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.services.vpn;
in
{
  imports = [ ./microvm-network.nix ];
  options.services.vpn = {
    enable = lib.mkEnableOption "the private WireGuard container";
    storageDirectory = lib.mkOption {
      type = lib.types.strMatching "/storage/(nvme|sata)/containers/vpn";
      default = "/storage/nvme/containers/vpn";
      description = "Directory for persistent WireGuard container data.";
    };
    uplink = lib.mkOption {
      type = lib.types.str;
      default = "eno1";
      description = "Host interface for public guest IPv4 traffic.";
    };
  };
  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "wireguard" ];
    networking.microvm.guests.vpn = {
      type = "veth";
      interface = "vpn-tap";
      hostAddress = "10.78.0.1";
      guestAddress = "10.78.0.2";
      inherit (cfg) uplink;
      publicUDPPorts = [ 51820 ];
    };
    systemd.tmpfiles.rules = [
      "d ${cfg.storageDirectory} 0700 root root -"
      "d ${cfg.storageDirectory}/wireguard 0700 root root -"
    ];
    containers.vpn = {
      autoStart = true;
      ephemeral = true;
      privateNetwork = true;
      privateUsers = "pick";
      additionalCapabilities = [ "CAP_NET_ADMIN" ];
      # Preserve the existing firewall interface name. Map container root onto the private state directory.
      extraFlags = [
        "--network-veth-extra=vpn-tap:eth0"
        "--bind=${cfg.storageDirectory}/wireguard:/var/lib/wg-ez:idmap"
      ];
      specialArgs = { inherit inputs; };
      config = import ./guests/vpn.nix;
    };
    systemd.services."container@vpn" = {
      requires = [ "nftables.service" ];
      bindsTo = [ "nftables.service" ];
      wants = [ "systemd-networkd.service" ];
      after = [
        "nftables.service"
        "systemd-networkd.service"
      ];
      unitConfig.RequiresMountsFor = [ cfg.storageDirectory ];
      serviceConfig = {
        CPUQuota = "100%";
        CPUWeight = 50;
        MemoryMax = "256M";
        TasksMax = 256;
      };
    };
    # Bind management to Tailscale. Keep the existing host-to-guest proxy and port.
    systemd.sockets.vpn-portal = {
      wantedBy = [ "sockets.target" ];
      listenStreams = [ "0.0.0.0:51821" ];
      socketConfig.BindToDevice = "tailscale0";
    };
    systemd.services.vpn-portal = {
      requires = [ "container@vpn.service" ];
      after = [ "container@vpn.service" ];
      serviceConfig = {
        ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd 10.78.0.2:8888";
        DynamicUser = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_UNIX"
        ];
      };
    };
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 51821 ];
  };
}
