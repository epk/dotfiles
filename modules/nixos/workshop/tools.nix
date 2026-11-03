# Optional workshop tools and their services: paseo, bb, cua, amp and omp. modules/nixos/workshop/guest.nix imports it.
{
  lib,
  pkgs,
  workshop,
  agentUnit,
  agentPath,
  ...
}:
let
  cfg = workshop.tools;
  service = lib.recursiveUpdate agentUnit {
    wants = [
      "network-online.target"
      "tailscaled.service"
    ];
    after = [
      "network-online.target"
      "tailscaled.service"
      "workshop-display.service"
    ];
    environment.PATH = lib.mkForce agentPath;
    serviceConfig = {
      WorkingDirectory = "/home/agent/workspace";
      RestartSec = 5;
      NoNewPrivileges = true;
    };
  };
  # The services wait for the Tailscale address. Fail and restart if the guest has no Tailscale login.
  waitForTailscale = ''
    while ! ip=$(${pkgs.tailscale}/bin/tailscale ip -4 2>/dev/null) || [ -z "$ip" ]; do
      sleep 2
    done
  '';
in
{
  config = lib.mkMerge [
    {
      environment.systemPackages =
        lib.optional cfg.paseo.enable pkgs.paseo
        ++ lib.optional cfg.bb.enable pkgs.bb-app
        ++ lib.optional cfg.pomerado.enable pkgs.pomerado
        ++ lib.optional cfg.amp.enable pkgs.amp-cli
        ++ lib.optional cfg.omp.enable pkgs.omp
        ++ lib.optionals cfg.cua.enable [
          pkgs.cua-cli
          pkgs.cua-driver
          pkgs.cua-spacesd
        ];
      networking.firewall.interfaces.tailscale0.allowedTCPPorts =
        lib.optional cfg.paseo.enable 6767
        ++ lib.optional cfg.bb.enable 38886
        ++ lib.optional cfg.cua.enable 3211;
      systemd.tmpfiles.rules = [
        "d /home/agent/.config 0700 agent agent -"
        "d /home/agent/.config/workshop 0700 agent agent -"
        "d /home/agent/integrations 0700 agent agent -"
      ];
    }
    (lib.mkIf cfg.paseo.enable {
      systemd.services.workshop-paseo = lib.recursiveUpdate service {
        description = "Workshop Paseo server";
        environment = {
          PASEO_HOME = "/home/agent/.paseo";
          PASEO_LISTEN = "0.0.0.0:6767";
          PASEO_RELAY_ENABLED = "false";
          PASEO_WEB_UI_ENABLED = "true";
        };
        preStart = ''
          set -eu
          mkdir -p "$HOME/.paseo"
          credentials="$HOME/.paseo/server.env"
          if [ ! -s "$credentials" ] || ! ${pkgs.gnugrep}/bin/grep -q '^PASEO_PASSWORD=.' "$credentials"; then
            umask 077
            password=$(${pkgs.openssl}/bin/openssl rand -hex 24)
            printf 'PASEO_PASSWORD=%s\n' "$password" > "$credentials.new"
            mv "$credentials.new" "$credentials"
          fi
          ${waitForTailscale}
          printf 'PASEO_HOSTNAMES=localhost,127.0.0.1,workshop,%s\n' "$ip" > /run/workshop-paseo/access.env
        '';
        serviceConfig = {
          TimeoutStartSec = "5min";
          RuntimeDirectory = "workshop-paseo";
          RuntimeDirectoryMode = "0700";
          EnvironmentFile = [
            "-/home/agent/.paseo/server.env"
            "-/run/workshop-paseo/access.env"
          ];
          ExecStart = "${pkgs.paseo}/bin/paseo daemon run";
        };
      };
    })
    (lib.mkIf cfg.bb.enable {
      systemd.services.workshop-bb = lib.recursiveUpdate service {
        description = "Workshop bb server";
        environment = {
          BB_TELEMETRY = "false";
          BB_DATA_DIR = "/home/agent/.bb";
        };
        preStart = ''
          ${waitForTailscale}
          printf 'BB_APP_URL=http://%s:38886\n' "$ip" > /run/workshop-bb/access.env
        '';
        serviceConfig = {
          TimeoutStartSec = "5min";
          RuntimeDirectory = "workshop-bb";
          RuntimeDirectoryMode = "0700";
          EnvironmentFile = "-/run/workshop-bb/access.env";
          ExecStart = "${pkgs.bb-app}/bin/bb-app --no-in-app-updates --server-bind-host 0.0.0.0";
        };
      };
    })
    (lib.mkIf cfg.cua.enable {
      services.gnome.at-spi2-core.enable = true;
      systemd.services.workshop-cua-driver = lib.recursiveUpdate service {
        description = "Workshop Cua Driver";
        requires = [ "workshop-display.service" ];
        serviceConfig.ExecStart = "${pkgs.cua-driver}/bin/cua-driver serve";
      };
      systemd.services.workshop-cua-desktop = lib.recursiveUpdate service {
        description = "Workshop Cua desktop endpoint";
        requires = [ "workshop-display.service" ];
        preStart = ''
          set -eu
          directory="$HOME/.config/workshop"
          if [ ! -s "$directory/cua-token" ]; then
            umask 077
            ${pkgs.openssl}/bin/openssl rand -hex 32 > "$directory/cua-token"
          fi
        '';
        serviceConfig.ExecStart = "${pkgs.cua-spacesd}/bin/cua-spacesd serve --listen 0.0.0.0:3211 --quic-port 0 --token-file /home/agent/.config/workshop/cua-token --data-dir /home/agent/.local/state/cua-spacesd";
      };
    })
  ];
}
