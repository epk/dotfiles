{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.workshop;
  state = "${config.microvm.stateDir}/workshop";
  disks = cfg.storageDirectory;
  vm = config.microvm.vms.workshop.config;
  guest = vm.config;
  # The same paths as the microvm.nix store disk: the guest system and its registration.
  storeContents = vm.pkgs.writeClosure (
    [ guest.system.build.toplevel ]
    ++ lib.optional guest.nix.enable (
      vm.pkgs.closureInfo { rootPaths = [ guest.system.build.toplevel ]; }
    )
  );
in
{
  imports = [
    ./microvm-storage.nix
    ./microvm-network.nix
  ];
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
        inherit inputs;
      };
      config = ./guests/workshop.nix;
    };
    systemd.services."microvm@workshop" = {
      serviceConfig = {
        CPUQuota = "200%";
        CPUWeight = 50;
        MemoryMax = "5G";
        TasksMax = 2048;
        UMask = "0077";
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
    # Systemd creates the mount points in the jail root as root. A RuntimeDirectory would belong to the VM user.
    systemd.tmpfiles.settings."10-workshop-jail"."/run/workshop-jail".d = {
      user = "root";
      group = "root";
      mode = "0755";
    };
    # Firecracker cannot share the host store, so the guest boots from an image of its closure.
    # The host builds that image from its local store. Then a deployment carries no 3.6 GB image.
    systemd.services.workshop-store-disk = {
      description = "Store image of the workshop guest";
      requiredBy = [ "microvm@workshop.service" ];
      before = [ "microvm@workshop.service" ];
      # The preparation service creates the directory for the image.
      requires = [ "prepare-microvm-storage-workshop.service" ];
      after = [ "prepare-microvm-storage-workshop.service" ];
      unitConfig.RequiresMountsFor = [ disks ];
      path = [
        pkgs.bubblewrap
        pkgs.erofs-utils
        pkgs.util-linux
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -euo pipefail
        image=${disks}/store.erofs
        if [ -s "$image" ] && [ "$(cat "$image.contents" 2>/dev/null)" = ${storeContents} ]; then
          exit 0
        fi
        rm -f "$image.new" "$image.contents"
        binds=()
        for path in $(sort -u ${storeContents}); do
          binds+=(--ro-bind "$path" "/run/workshop-store/$(basename "$path")")
        done
        bwrap --dev-bind / / --tmpfs /run/workshop-store "''${binds[@]}" -- \
          mkfs.erofs ${lib.escapeShellArgs guest.microvm.storeDiskErofsFlags} -T 0 --all-root -L nix-store \
          --mount-point=/nix/store "$image.new" /run/workshop-store
        # The guest mounts the image by this label.
        blkid -p -s LABEL -o value "$image.new" | grep -qx nix-store
        mv "$image.new" "$image"
        echo ${storeContents} >"$image.contents"
      '';
    };
    networking.microvm.guests.workshop = {
      interface = "workshop-tap";
      hostAddress = "10.77.0.1";
      guestAddress = "10.77.0.2";
      inherit (cfg) uplink;
    };
  };
}
