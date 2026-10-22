{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.vpn;
  state = "${config.microvm.stateDir}/vpn";
in
{
  imports = [
    ./microvm-storage.nix
    ./microvm-network.nix
  ];
  options.services.vpn = {
    enable = lib.mkEnableOption "the private WireGuard appliance";
    storageDirectory = lib.mkOption {
      type = lib.types.strMatching "/storage/(nvme|sata)/vms/vpn";
      default = "/storage/nvme/vms/vpn";
      description = "Directory for the persistent VPN disk.";
    };
    uplink = lib.mkOption {
      type = lib.types.str;
      default = "eno1";
    };
    administratorKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };
  config = lib.mkIf cfg.enable {
    microvm.vms.vpn = {
      pkgs = null;
      specialArgs.vpn = cfg;
      config = ./guests/vpn.nix;
    };
    networking.microvm.guests.vpn = {
      interface = "vpn-tap";
      hostAddress = "10.78.0.1";
      guestAddress = "10.78.0.2";
      inherit (cfg) uplink;
      publicUDPPorts = [ 51820 ];
    };
    # Bind the management socket to Tailscale. The proxy makes a separate host-to-guest connection.
    systemd.sockets.vpn-portal = {
      wantedBy = [ "sockets.target" ];
      listenStreams = [ "0.0.0.0:51821" ];
      socketConfig.BindToDevice = "tailscale0";
    };
    systemd.services.vpn-portal = {
      requires = [ "microvm@vpn.service" ];
      after = [ "microvm@vpn.service" ];
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
    # Pass endpoint metadata in a read-only disk. Keep private access addresses outside Git and the store.
    systemd.services.vpn-host-config = {
      requiredBy = [ "microvm@vpn.service" ];
      before = [ "microvm@vpn.service" ];
      requires = [ "prepare-microvm-storage-vpn.service" ];
      after = [
        "prepare-microvm-storage-vpn.service"
        "tailscaled.service"
      ];
      path = [
        pkgs.e2fsprogs
        pkgs.tailscale
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "vpn-host-config";
        UMask = "0077";
      };
      script = ''
        set -eu
        address=$(tailscale ip -4 2>/dev/null || true)
        if [ -n "$address" ]; then url="http://$address:51821"; else url="http://localhost:51821"; fi
        printf 'WG_PORTAL_WEB_EXTERNAL_URL=%s\n' "$url" > /run/vpn-host-config/portal.env
        chmod 0444 /run/vpn-host-config/portal.env
        image=${cfg.storageDirectory}/host-config.raw
        truncate -s 8M "$image.new"
        mkfs.ext4 -q -m 0 -E nodiscard -d /run/vpn-host-config "$image.new"
        chown root:kvm "$image.new"
        chmod 0640 "$image.new"
        mv "$image.new" "$image"
      '';
    };
    systemd.tmpfiles.settings."10-vpn-jail"."/run/vpn-jail".d = {
      user = "root";
      group = "root";
      mode = "0755";
    };
    systemd.services."microvm@vpn".serviceConfig = {
      CPUQuota = "100%";
      CPUWeight = 50;
      MemoryMax = "768M";
      TasksMax = 256;
      UMask = "0077";
      RootDirectory = "/run/vpn-jail";
      BindReadOnlyPaths = [ "/nix/store" ];
      BindPaths = [
        state
        cfg.storageDirectory
        "/dev/kvm"
        "/dev/net/tun"
      ];
      ReadWritePaths = [
        state
        cfg.storageDirectory
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
}
