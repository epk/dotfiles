{
  pkgs,
  nixpkgs,
  metadata,
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

  users.users.${metadata.server.username} = {
    isNormalUser = true;
    uid = 1000;
    home = "/home/${metadata.server.username}";
    extraGroups = [ "wheel" ];
    shell = pkgs.bashInteractive;
    openssh.authorizedKeys.keys = metadata.server.authorizedKeys;
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
  };
  # Keep a GC root for each guest system closure that uses the shared store.
  # Run store collection manually until the configuration defines guest retention.
  nix.gc.automatic = false;
  # microvm.nix enables KSM. Shared pages across guests leak memory timing between them.
  hardware.ksm.enable = false;
  services.fstrim.enable = true;
  services.journald.settings.Journal.SystemMaxUse = "256M";
  documentation.nixos.enable = false;
  time.timeZone = "UTC";
}
