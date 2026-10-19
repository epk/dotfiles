{
  pkgs,
  config,
  ...
}:

{
  imports = [
    ../../modules/nixos/server.nix
    ./hardware-configuration.nix
    ./disko.nix
    ./secrets.nix
    ../../modules/nixos/workshop.nix
    ../../modules/nixos/server-automation.nix
    ../../modules/nixos/home.nix
  ];
  services.workshop = {
    enable = true;
    administratorKeys = config.users.users.${config.dotfiles.homeUser}.openssh.authorizedKeys.keys;
  };
  networking.hostName = "servnerr";
  # Use the wired interface for host access.
  networking.useDHCP = false;
  networking.interfaces.eno1.useDHCP = true;
  # Keep the current network connection during activation.
  systemd.services.dhcpcd.restartIfChanged = false;
  systemd.services.network-addresses-eno1.restartIfChanged = false;
  # Keep the existing resolver. Networkd configures only guest TAP devices.
  services.resolved.enable = false;
  networking.nameservers = [
    "1.1.1.1"
    "2606:4700:4700::1111"
  ];
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 5;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  system.stateVersion = "26.05";

}
