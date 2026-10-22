{
  name,
  description,
  guest,
  cpuQuota,
  memoryMax,
  tasksMax,
}:
{
  config,
  lib,
  ...
}:
let
  cfg = config.services.${name};
  state = "${config.microvm.stateDir}/${name}";
in
{
  imports = [
    ./microvm-storage.nix
    ./microvm-network.nix
  ];
  options.services.${name} = {
    enable = lib.mkEnableOption description;
    storageDirectory = lib.mkOption {
      type = lib.types.strMatching "/storage/(nvme|sata)/vms/${name}";
      default = "/storage/nvme/vms/${name}";
      description = "Directory for the persistent guest disks.";
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
    microvm.vms.${name} = {
      # The guest evaluates its own nixpkgs, so its unfree and problem settings apply.
      pkgs = null;
      specialArgs.${name} = cfg;
      config = guest;
    };
    # Systemd creates the mount points in the jail root as root. A RuntimeDirectory would belong to the VM user.
    systemd.tmpfiles.settings."10-${name}-jail"."/run/${name}-jail".d = {
      user = "root";
      group = "root";
      mode = "0755";
    };
    systemd.services."microvm@${name}".serviceConfig = {
      CPUQuota = cpuQuota;
      CPUWeight = 50;
      MemoryMax = memoryMax;
      TasksMax = tasksMax;
      UMask = "0077";
      RootDirectory = "/run/${name}-jail";
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
