let
  labelPrefix = "servnerr";
  mountOptions = [
    "noatime"
    "compress=zstd:1"
    "discard=async"
  ];
  dataOptions = mountOptions ++ [
    "nodev"
    "nosuid"
    "nofail"
    "x-systemd.device-timeout=10s"
  ];
in
{
  # Root and Nix share the physical 32 GiB host partition.
  disko.devices.disk = {
    system = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-eui.001b448b46826616";
      content = {
        type = "gpt";
        partitions = {
          esp = {
            priority = 1;
            label = "${labelPrefix}-esp";
            type = "EF00";
            start = "2048";
            end = "1050623";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          fast = {
            priority = 2;
            label = "${labelPrefix}-fast";
            start = "1050624";
            end = "433008639";
            content = {
              type = "btrfs";
              extraArgs = [
                "-L"
                "${labelPrefix}-fast"
              ];
              subvolumes = {
                "@fast" = {
                  mountpoint = "/storage/nvme";
                  mountOptions = dataOptions;
                };
                "@artifacts" = {
                  mountpoint = "/storage/nvme/artifacts";
                  mountOptions = dataOptions;
                };
                "@vms" = {
                  mountpoint = "/storage/nvme/vms";
                  mountOptions = dataOptions;
                };
              };
            };
          };
          root = {
            priority = 3;
            label = "${labelPrefix}-root";
            start = "433008640";
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [
                "-L"
                "${labelPrefix}-root"
              ];
              subvolumes = {
                "@root" = {
                  mountpoint = "/";
                  inherit mountOptions;
                };
                "@nix" = {
                  mountpoint = "/nix";
                  inherit mountOptions;
                };
              };
            };
          };
        };
      };
    };
    data = {
      type = "disk";
      device = "/dev/disk/by-id/wwn-0x5001b448bcff9484";
      content = {
        type = "gpt";
        partitions.data = {
          label = "${labelPrefix}-data";
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [
              "-L"
              "${labelPrefix}-data"
            ];
            subvolumes = {
              "@data" = {
                mountpoint = "/storage/sata";
                mountOptions = dataOptions;
              };
              "@artifacts" = {
                mountpoint = "/storage/sata/artifacts";
                mountOptions = dataOptions;
              };
              "@shares" = {
                mountpoint = "/storage/sata/shares";
                mountOptions = dataOptions;
              };
              "@vms" = {
                mountpoint = "/storage/sata/vms";
                mountOptions = dataOptions;
              };
            };
          };
        };
      };
    };
  };
  fileSystems."/nix".neededForBoot = true;
  # A wrong label prefix would break the next boot. Refuse to switch to it.
  system.preSwitchChecks.partitionLabels = ''
    for part in esp root; do
      test -e "/dev/disk/by-partlabel/${labelPrefix}-$part"
    done
  '';
  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [
      "/"
      "/storage/nvme"
      "/storage/sata"
    ];
  };
  systemd.tmpfiles.rules = [
    "d /storage/nvme/vms 0711 root root -"
    "d /storage/nvme/artifacts 0750 root root -"
    "d /storage/sata/vms 0711 root root -"
    "d /storage/sata/shares 0750 root root -"
    "d /storage/sata/artifacts 0750 root root -"
  ];
}
