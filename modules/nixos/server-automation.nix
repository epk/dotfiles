{
  config,
  pkgs,
  ...
}:
{
  system.autoUpgrade = {
    enable = true;
    flake = "github:epk/dotfiles#server";
    upgrade = false;
    dates = "hourly";
    randomizedDelaySec = "5min";
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
      "--hostname=${config.networking.hostName}"
      "--advertise-exit-node"
      "--advertise-tags=tag:exit-node"
      "--ssh"
    ];
  };

  # Upstream logs in once at boot. Retry a failed login.
  systemd.services.tailscaled-autoconnect.serviceConfig = {
    Restart = "on-failure";
    RestartSec = "30s";
  };
}
