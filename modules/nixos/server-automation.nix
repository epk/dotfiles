{
  config,
  lib,
  metadata,
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
    authKeyFile = config.age.secrets.tailscale-auth.path;
    extraUpFlags = [
      "--hostname=${metadata.server.hostName}"
      "--advertise-exit-node"
      "--advertise-tags=tag:exit-node"
      "--ssh"
    ];
  };

  # Keep the key out of process arguments. Authenticate only when login is required.
  systemd.services.tailscaled-autoconnect = {
    serviceConfig = {
      Type = lib.mkForce "oneshot";
      TimeoutStartSec = "2min";
    };
    script = lib.mkForce ''
      while state="$(tailscale status --json --peers=false | jq -r '.BackendState')"; do
        case "$state" in
          Running) exit 0 ;;
          NeedsLogin)
            tailscale up --auth-key=file:${lib.escapeShellArg config.services.tailscale.authKeyFile} ${lib.escapeShellArgs config.services.tailscale.extraUpFlags}
            exit 0
            ;;
          Starting|NoState) sleep 1 ;;
          *) echo "Tailscale does not require automatic login." >&2; exit 1 ;;
        esac
      done
      exit 1
    '';
  };
}
