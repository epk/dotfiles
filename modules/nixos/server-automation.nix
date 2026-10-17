{
  config,
  metadata,
  pkgs,
  ...
}:
{
  system.autoUpgrade = {
    enable = true;
    flake = "github:epk/dotfiles#server";
    flags = [ "--impure" ];
    upgrade = false;
    dates = "hourly";
    randomizedDelaySec = "5min";
  };

  age.secrets.private-metadata = {
    file = ../../secrets/private/metadata.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };
  systemd.services.nixos-upgrade = {
    environment.DOTFILES_PRIVATE_CONFIG = config.age.secrets.private-metadata.path;
    unitConfig.ConditionPathExists = config.age.secrets.private-metadata.path;
  };
  age.secrets.tailscale-auth = {
    file = ../../secrets/tailscale/server.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };
  services.tailscale = {
    # Upstream passes this file's content to --auth-key. A file: reference keeps the secret out of process arguments.
    authKeyFile = pkgs.writeText "tailscale-auth-key" "file:${config.age.secrets.tailscale-auth.path}";
    extraUpFlags = [
      "--hostname=${metadata.server.hostName}"
      "--advertise-exit-node"
      "--advertise-tags=tag:exit-node"
      "--ssh"
    ];
  };
}
