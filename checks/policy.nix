{ self, pkgs }:
let
  inherit (pkgs) lib;
  host = self.nixosConfigurations.server;
  config = host.config;
  darwin = self.darwinConfigurations;
  homeOf = c: c.config.home-manager.users.${c.config.system.primaryUser};
  workshop = config.microvm.vms.workshop.config.config;
  workshopUnit = config.systemd.services."microvm@workshop".serviceConfig;
  workshopNetwork = config.systemd.services.workshop-network.script;
  checked =
    (host.extendModules {
      modules = [
        {
          microvm.vms.policy-check.config = {
            imports = [ ../modules/nixos/microvm-guest.nix ];
            networking.hostName = "policy-check";
            microvm.vsock.cid = 42;
            microvm.volumes = [
              {
                image = "/storage/nvme/vms/policy-check/state.raw";
                mountPoint = "/var";
                size = 4096;
                imageType = "raw";
                fsType = "ext4";
                direct = false;
                autoCreate = false;
              }
              {
                image = "/storage/sata/vms/policy-check/data.raw";
                mountPoint = "/data";
                size = 16384;
                imageType = "raw";
                fsType = "ext4";
                direct = false;
                autoCreate = false;
              }
            ];
          };
        }
      ];
    }).config;
  guest = checked.microvm.vms.policy-check.config.config;
  filesystems = map (mount: config.fileSystems.${mount}) [
    "/"
    "/nix"
    "/storage/nvme"
    "/storage/nvme/artifacts"
    "/storage/nvme/vms"
    "/storage/sata"
    "/storage/sata/artifacts"
    "/storage/sata/shares"
    "/storage/sata/vms"
  ];
in
# Keep the initrd mount option. Without this option, remote access can fail.
assert builtins.all (mount: builtins.elem "x-initrd.mount" config.fileSystems.${mount}.options) [
  "/"
  "/nix"
];
assert config.fileSystems."/nix".neededForBoot;
assert config.fileSystems."/".device == config.fileSystems."/nix".device;
assert config.fileSystems."/".device != config.fileSystems."/storage/nvme".device;
assert !(config.fileSystems ? "/persist");
assert builtins.all (
  fs:
  fs.fsType == "btrfs"
  && builtins.all (option: builtins.elem option fs.options) [
    "noatime"
    "compress=zstd:1"
    "discard=async"
  ]
  && !builtins.any (option: builtins.elem option fs.options) [
    "nodatacow"
    "nodatasum"
    "autodefrag"
    "nobarrier"
  ]
) filesystems;
assert !(config.systemd.services ? server-snapshots);
assert !(config.fileSystems ? "/.snapshots");
assert !(config.fileSystems ? "/nix/.snapshots");
assert !(config.fileSystems ? "/storage/sata/.snapshots");
assert config.services.fstrim.enable && config.services.btrfs.autoScrub.enable;
assert builtins.all (assertion: assertion.assertion) checked.assertions;
assert guest.microvm.hypervisor == "cloud-hypervisor";
assert builtins.all (
  volume:
  volume.readOnly
  || (volume.imageType == "raw" && volume.fsType == "ext4" && !volume.direct && !volume.autoCreate)
) guest.microvm.volumes;
assert builtins.any (
  share: share.source == "/nix/store" && share.readOnly && share.proto == "virtiofs"
) guest.microvm.shares;
assert (builtins.head guest.microvm.volumes).image == "/storage/nvme/vms/policy-check/state.raw";
assert builtins.elem "/storage/sata/vms/policy-check"
  checked.systemd.services."prepare-microvm-storage-policy-check".unitConfig.RequiresMountsFor;
assert checked.systemd.services."microvm@policy-check".serviceConfig.User == "vm-policy-check";
assert builtins.stringLength checked.system.build.toplevel.drvPath > 0;
assert lib.all (n: lib.hasInfix "--hostname ${n} " (homeOf darwin.${n}).programs.zsh.initContent) (
  lib.attrNames darwin
);
assert lib.all (c: (homeOf c).programs.nh.flake != null) (lib.attrValues darwin);
assert lib.hasInfix "host: [${lib.concatStringsSep ", " (lib.attrNames darwin)}]" (
  builtins.readFile ../.github/workflows/check.yml
);
assert self.packages.aarch64-darwin ? age;
# The upgrade service builds an existing output.
assert self.nixosConfigurations ? ${lib.last (lib.splitString "#" config.system.autoUpgrade.flake)};
# The upstream autoconnect reads the key through the file: reference, not as a process argument.
# A store file holds no secret, so its content in the arguments is public.
assert lib.hasPrefix builtins.storeDir config.services.tailscale.authKeyFile;
assert lib.hasInfix
  (builtins.unsafeDiscardStringContext ''--auth-key "$(cat ${config.services.tailscale.authKeyFile})"'')
  (builtins.unsafeDiscardStringContext config.systemd.services.tailscaled-autoconnect.script);
# The workshop guest keeps its isolation. Builds cannot detect a change to these values.
assert workshop.microvm.hypervisor == "firecracker";
# The guest mounts disks by position: the store disk, then the volumes in order.
assert
  map (d: d.path_on_host) workshop.microvm.firecracker.extraConfig.drives
  == [ workshop.microvm.storeDisk ] ++ map (v: v.image) workshop.microvm.volumes;
assert lib.hasInfix "user vm-workshop" workshop.microvm.binScripts.tap-up;
assert workshopUnit.User == "vm-workshop" && workshopUnit.CapabilityBoundingSet == "";
assert workshopUnit.RootDirectory == "/run/workshop-jail" && workshopUnit.IPAddressDeny == "any";
assert lib.all (net: lib.hasInfix net workshopNetwork) [
  "100.64.0.0/10"
  "192.168.0.0/16"
  "--dst-type LOCAL -j REJECT"
];
pkgs.runCommand "policy" { } "touch $out"
