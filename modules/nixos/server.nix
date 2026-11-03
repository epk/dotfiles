{
  config,
  inputs,
  pkgs,
  ...
}:
{
  imports = [ ./base.nix ];
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

  environment.systemPackages = with pkgs; [
    gitMinimal
    jq
    ripgrep
    tmux
    curl
    netcat-openbsd
  ];
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.settings = {
    max-jobs = 1;
    cores = 2;
  };
  # Determinate Nixd collects unreferenced paths. It does not delete old generations.
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
}
