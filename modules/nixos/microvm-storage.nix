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
      assertion = builtins.match "[a-z][a-z0-9-]{0,27}" name != null;
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
    {
      # virtiofsd creates its sockets in the state directory. The VMM looks for them in its working directory.
      assertion = (guest name).microvm.shares == [ ];
      message = "VM ${name}: Shares need a socket path for the root-owned state directory. Do not use microvm.shares.";
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
    // lib.mergeAttrsList (
      map (name: {
        # Root units run commands from this directory. The VM user writes only its API socket.
        "${stateDir}/${name}".d = {
          user = "root";
          group = "root";
          mode = "0755";
        };
        "${stateDir}/${name}/run".d = {
          user = "vm-${name}";
          group = "kvm";
          mode = "0700";
        };
      }) names
    )
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
            chown root:root "$directory"
            chmod 0755 "$directory"
            image=${lib.escapeShellArg volume.image}
            # chown and chmod follow a link. Before this directory was root-owned, the VM user could add one.
            if [ -L "$image" ]; then echo "Cannot use link $image as a disk" >&2; exit 1; fi
            # Create the image under a temporary name, so an interrupted run leaves no half-made disk.
            if [ ! -e "$image" ]; then
              rm -f "$image.tmp"
              truncate -s ${toString volume.size}M "$image.tmp"
              mkfs.ext4 -q -m 0 -E nodiscard "$image.tmp"
              mv "$image.tmp" "$image"
            fi
            flags=$(lsattr -d "$image")
            flags=''${flags%% *}
            case "$flags" in *C*) echo "Cannot use NOCOW disk $image" >&2; exit 1 ;; esac
            chown vm-${name}:kvm "$image"
            chmod 0600 "$image"
          '') (disks name)}
        '';
      };
      "microvm@${name}".serviceConfig = {
        User = lib.mkForce "vm-${name}";
        Group = lib.mkForce "kvm";
        # The runner creates its API socket in the working directory.
        WorkingDirectory = "${stateDir}/${name}/run";
      };
      # Root writes the booted link, because root units run its stop commands.
      "microvm-set-booted@${name}" = {
        overrideStrategy = "asDropin";
        serviceConfig = {
          User = "root";
          Group = "root";
        };
      };
    }
  ) { } names;
}
