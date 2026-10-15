{
  config,
  lib,
  pkgs,
  ...
}:
{
  # The host creates sparse disk images.
  # Upstream autoCreate sets NOCOW, which disables data checksums and compression.
  # Disable autoCreate to keep CoW, data checksums and compression.
  microvm = {
    hypervisor = lib.mkDefault "cloud-hypervisor";
    vcpu = lib.mkDefault 1;
    mem = lib.mkDefault 512;
    balloon = lib.mkDefault true;
    shares = lib.mkDefault [
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
        readOnly = true;
      }
    ];
    volumes = lib.mkDefault [
      {
        image = "/storage/nvme/vms/${config.networking.hostName}/state.raw";
        mountPoint = "/var";
        size = 4096;
        imageType = "raw";
        fsType = "ext4";
        direct = false;
        autoCreate = false;
      }
    ];
    writableStoreOverlay = lib.mkDefault null;
  };
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
  documentation.nixos.enable = lib.mkDefault false;
  networking.firewall.enable = lib.mkDefault true;
  services.fstrim.enable = lib.mkDefault true;
  system.stateVersion = lib.mkDefault "26.05";
}
