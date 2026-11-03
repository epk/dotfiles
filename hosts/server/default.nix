# The server: its services, network and boot loader. flake.nix builds it as server.
{ config, ... }:

{
  imports = [
    ../../modules/nixos/server.nix
    ./hardware-configuration.nix
    ./disko.nix
    ./secrets.nix
    ../../modules/nixos/workshop/host.nix
    ../../modules/nixos/vpn/host.nix
    ../../modules/nixos/server-automation.nix
    ../../modules/nixos/home.nix
  ];

  services.workshop = {
    enable = true;
    administratorKeys = config.users.users.${config.dotfiles.homeUser}.openssh.authorizedKeys.keys;
    tools = {
      browser.enable = true;
      claudeCode.enable = true;
      codex.enable = true;
      gemini.enable = true;
      antigravity.enable = true;
      paseo.enable = true;
      bb.enable = true;
      cua.enable = true;
      amp.enable = true;
      pomerado.enable = true;
      omp.enable = true;
    };
  };
  services.vpn.enable = true;
  networking.hostName = "servnerr";
  # Use the wired interface for host access.
  networking.useDHCP = false;
  networking.interfaces.eno1.useDHCP = true;
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
}
