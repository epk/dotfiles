{
  config,
  pkgs,
  nixpkgs,
  ...
}:
{
  imports = [ ./caches.nix ];
  nixpkgs.overlays = [ (import ../../packages/tailscale.nix) ];
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  services.tailscale = {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "server";
  };
  users.users.${config.dotfiles.homeUser} = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ (import ../../lib/user.nix).sshPublicKey ];
  };
  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    gitMinimal
    jq
    ripgrep
    tmux
    curl
    netcat-openbsd
  ];
  nix.registry.nixpkgs.flake = nixpkgs;
  nix.channel.enable = false;
  nix.settings = {
    max-jobs = 1;
    cores = 2;
    # Only root can change daemon trust or select privileged builders.
    trusted-users = [ "root" ];
    # The host filesystem also holds builds. Collect garbage before it fills.
    min-free = 4 * 1024 * 1024 * 1024;
    max-free = 8 * 1024 * 1024 * 1024;
  };
  # The current system references every guest closure. Old generations are the rollback window.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  # microvm.nix enables KSM. Shared pages across guests leak memory timing between them.
  hardware.ksm.enable = false;
  services.fstrim.enable = true;
  services.journald.settings.Journal.SystemMaxUse = "256M";
  documentation.nixos.enable = false;
  time.timeZone = "UTC";
}
