{
  config,
  lib,
  pkgs,
  ...
}:
let
  names = builtins.attrNames config.microvm.vms;
  guest =
    name:
    let
      vm = config.microvm.vms.${name};
    in
    if vm.evaluatedConfig != null then vm.evaluatedConfig.config else vm.config.config;
  disks = name: builtins.filter (volume: !volume.readOnly) (guest name).microvm.volumes;
  stateDir = config.microvm.stateDir;
in
{
  microvm.host.installCommand = false;
  assertions = lib.concatMap (name: [
    {
      assertion = builtins.match "[a-z][a-z0-9-]{0,30}" name != null;
      message = "Use short VM names with lowercase letters, digits and hyphens.";
    }
    {
      assertion = config.microvm.vms.${name}.flake == null;
      message = "Define each VM in microvm.vms. Do not use an external flake.";
    }
    {
      assertion = builtins.all (
        volume:
        volume.imageType == "raw"
        && volume.fsType == "ext4"
        && !volume.direct
        && !volume.autoCreate
        && volume.size > 0
        && builtins.match "/storage/(nvme|sata)/vms/${name}/[A-Za-z0-9._-]+\\.raw" volume.image != null
      ) (disks name);
      message = "VM ${name}: Use private sparse raw ext4 disks under /storage/nvme/vms/${name}/ or /storage/sata/vms/${name}/. Disable direct I/O and autoCreate.";
    }
  ]) names;
  users.users = lib.genAttrs (map (name: "vm-${name}") names) (_: {
    isSystemUser = true;
    group = "kvm";
  });
  systemd.tmpfiles.settings."10-microvm" = lib.mkForce (
    {
      "${stateDir}".d = {
        user = "root";
        group = "root";
        mode = "0711";
      };
    }
    // lib.genAttrs (map (name: "${stateDir}/${name}") names) (path: {
      d = {
        user = "vm-${builtins.baseNameOf path}";
        group = "kvm";
        mode = "0700";
      };
    })
  );
  systemd.services = lib.foldl' (
    services: name:
    services
    // {
      "prepare-microvm-storage-${name}" = {
        description = "Private CoW sparse disks for VM ${name}";
        before = [ "microvm@${name}.service" ];
        requiredBy = [ "microvm@${name}.service" ];
        unitConfig.RequiresMountsFor = lib.unique (map (volume: builtins.dirOf volume.image) (disks name));
        path = [
          pkgs.btrfs-progs
          pkgs.coreutils
          pkgs.e2fsprogs
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          UMask = "0077";
        };
        script = ''
          set -euo pipefail
          ${lib.concatMapStringsSep "\n" (volume: ''
            directory=${lib.escapeShellArg (builtins.dirOf volume.image)}
            if [ ! -e "$directory" ]; then btrfs subvolume create "$directory"; fi
            btrfs subvolume show "$directory" >/dev/null
            chown vm-${name}:kvm "$directory"
            chmod 0700 "$directory"
            image=${lib.escapeShellArg volume.image}
            if [ ! -e "$image" ]; then
              truncate -s ${toString volume.size}M "$image"
              mkfs.ext4 -q -m 0 -E nodiscard "$image"
            fi
            flags=$(lsattr -d "$image")
            case "$flags" in *C*) echo "Cannot use NOCOW disk $image" >&2; exit 1 ;; esac
            chown vm-${name}:kvm "$image"
            chmod 0600 "$image"
          '') (disks name)}
        '';
      };
      "microvm@${name}".serviceConfig = {
        User = lib.mkForce "vm-${name}";
        Group = lib.mkForce "kvm";
      };
      "microvm-set-booted@${name}" = {
        overrideStrategy = "asDropin";
        serviceConfig = {
          User = "vm-${name}";
          Group = "kvm";
        };
      };
    }
  ) { } names;
}
