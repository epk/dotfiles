{
  config,
  lib,
  pkgs,
  ...
}:
let
  user = (import ../../lib/user.nix).username;
  tap = (lib.head config.microvm.interfaces).id;
in
{
  imports = [ ./caches.nix ];
  options.dotfiles.guestStoreImage = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Read-only Firecracker store drive image. Defaults to the microvm.nix store disk.";
  };
  config = {
    security.sudo.wheelNeedsPassword = false;
    time.timeZone = "UTC";
    services.journald.settings.Journal.SystemMaxUse = lib.mkDefault "64M";
    # The pinned Firecracker release does not support guest discard.
    services.fstrim.enable = false;
    boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
    documentation.nixos.enable = lib.mkDefault false;
    system.stateVersion = lib.mkDefault "26.11";
    networking = {
      useDHCP = false;
      enableIPv6 = false;
      usePredictableInterfaceNames = false;
      nameservers = [
        "1.1.1.1"
        "9.9.9.9"
      ];
    };
    services.openssh = {
      enable = true;
      hostKeys = [
        {
          path = "/var/lib/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        AllowUsers = [ user ];
      };
    };
    microvm = {
      hypervisor = "firecracker";
      balloon = false;
      shares = [ ];
      # Upstream gives the TAP device to the user microvm. This VM runs as its own host user.
      binScripts.tap-up = lib.mkForce ''
        set -eu
        # A crashed VM can leave its TAP device behind.
        ${pkgs.iproute2}/bin/ip link delete ${tap} 2>/dev/null || true
        ${pkgs.iproute2}/bin/ip tuntap add dev ${tap} mode tap user vm-${config.networking.hostName}
        ${pkgs.iproute2}/bin/ip link set ${tap} up
      '';
      # extraConfig replaces the upstream drive list. Writeback caching passes guest flushes to the host.
      # The host builds the workshop store image. See modules/nixos/workshop.nix.
      firecracker.extraConfig.drives = [
        {
          drive_id = "store";
          path_on_host =
            if config.dotfiles.guestStoreImage != null then
              config.dotfiles.guestStoreImage
            else
              config.microvm.storeDisk;
          is_root_device = false;
          is_read_only = true;
          io_engine = "Sync";
        }
      ]
      ++ map (volume: {
        drive_id = lib.removeSuffix ".raw" (baseNameOf volume.image);
        path_on_host = volume.image;
        is_root_device = false;
        is_read_only = volume.readOnly;
        io_engine = "Sync";
        cache_type = "Writeback";
      }) config.microvm.volumes;
    };
  };
}
