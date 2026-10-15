{
  pkgs,
  metadata,
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
  ];
  services.workshop = {
    enable = true;
    administratorKeys = config.users.users.${metadata.server.username}.openssh.authorizedKeys.keys;
  };
  system.switch.enable = metadata.private;
  networking.hostName = metadata.server.hostName;
  # Use the wired interface for host access.
  networking.useDHCP = false;
  networking.interfaces.eno1.useDHCP = true;
  # Keep the current network connection during activation.
  systemd.services.dhcpcd.restartIfChanged = false;
  systemd.services.network-addresses-eno1.restartIfChanged = false;
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
