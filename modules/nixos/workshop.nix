{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.workshop;
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
    (import ./microvm-service.nix {
      name = "workshop";
      description = "the persistent coding and browser guest";
      guest = ./guests/workshop.nix;
      cpuQuota = "200%";
      memoryMax = "5G";
      tasksMax = 2048;
    })
  ];
  options.services.workshop.tools = lib.mkOption {
    type = lib.types.submodule {
      options = import ../../lib/workshop-tools.nix { inherit lib; };
    };
    default = { };
    description = "Guest tools and their services. Disabling a tool preserves its data.";
  };
  config = lib.mkIf cfg.enable {
    microvm.vms.workshop.specialArgs.inputs = inputs;
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
