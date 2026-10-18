{
  config,
  pkgs,
  nixpkgs,
  ...
}:

{
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
  # Keep the current Tailscale tunnel during activation.
  # Boot starts the daemon from the new system closure.
  systemd.services.tailscaled.restartIfChanged = false;

  users.users.${config.dotfiles.homeUser} = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE/Cr+bIMxMzkk8dN7xxRsaJeHRifwlyTuh/ja9Uy9MN"
    ];
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
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    max-jobs = 1;
    cores = 2;
    # Only root can change daemon trust or select privileged builders.
    trusted-users = [ "root" ];
    # The 32 GiB root also holds builds. Collect garbage before it fills.
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
