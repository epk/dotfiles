{ self, pkgs }:
let
  inherit (pkgs) lib;
  host = self.nixosConfigurations.server;
  config = host.config;
  workshop = config.microvm.vms.workshop.config.config;
  workshopUnit = config.systemd.services."microvm@workshop".serviceConfig;
  workshopNetwork = config.networking.nftables.tables.microvm-filter.content;
in
# Keep the initrd mount option. Without this option, remote access can fail.
assert builtins.all (mount: builtins.elem "x-initrd.mount" config.fileSystems.${mount}.options) [
  "/"
  "/nix"
];
assert config.fileSystems."/nix".neededForBoot;
assert config.fileSystems."/".device == config.fileSystems."/nix".device;
assert config.fileSystems."/".device != config.fileSystems."/storage/nvme".device;
# The store file holds only a file: reference. No secret reaches process arguments.
assert lib.hasPrefix builtins.storeDir config.services.tailscale.authKeyFile;
# The workshop guest keeps its isolation. Builds cannot detect a change to these values.
assert workshop.microvm.hypervisor == "firecracker";
# The guest mounts disks by position: the store image, then the volumes in order.
assert
  map (d: d.path_on_host) workshop.microvm.firecracker.extraConfig.drives
  == [ "${config.services.workshop.storageDirectory}/store.erofs" ]
  ++ map (v: v.image) workshop.microvm.volumes;
# The host builds the store image. The server closure must not contain the microvm.nix image.
assert
  !lib.hasInfix "microvm-store-disk" (
    builtins.unsafeDiscardStringContext (builtins.toJSON workshop.microvm.firecracker.extraConfig)
  );
assert lib.hasInfix "user vm-workshop" workshop.microvm.binScripts.tap-up;
assert workshopUnit.User == "vm-workshop" && workshopUnit.CapabilityBoundingSet == "";
assert workshopUnit.RootDirectory == "/run/workshop-jail" && workshopUnit.IPAddressDeny == "any";
# Root units run commands from the VM state directory. The VM user must not own it.
assert config.systemd.tmpfiles.settings."10-microvm"."/var/lib/microvms/workshop".d.user == "root";
assert config.systemd.services."microvm-set-booted@workshop".serviceConfig.User == "root";
assert lib.all (net: lib.hasInfix net workshopNetwork) [
  "100.64.0.0/10"
  "192.168.0.0/16"
  "fib daddr type local counter drop"
];
pkgs.runCommand "policy" { } "touch $out"
