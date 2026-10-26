{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.workshopTools;
  bb = pkgs.callPackage ../../../packages/bb-app { };
  pomerado = pkgs.callPackage ../../../packages/pomerado { };
  cua = pkgs.callPackage ../../../packages/cua.nix { };
  service = {
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "workshop-display.service"
    ];
    environment = {
      HOME = "/home/agent";
      DISPLAY = ":0";
      XDG_RUNTIME_DIR = "/run/user/1001";
      DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/1001/bus";
      PATH = lib.mkForce "/etc/profiles/per-user/agent/bin:/run/current-system/sw/bin";
    };
    serviceConfig = {
      User = "agent";
      Group = "agent";
      WorkingDirectory = "/home/agent/workspace";
      UMask = "0077";
      Restart = "on-failure";
      RestartSec = 5;
      NoNewPrivileges = true;
    };
  };
in
{
  options.services.workshopTools = lib.mkOption {
    type = lib.types.submodule {
      options = import ../../../lib/workshop-tools.nix { inherit lib; };
    };
    default = { };
    description = "Tools installed only inside Workshop.";
  };
  config = lib.mkMerge [
    {
      environment.systemPackages =
        lib.optional cfg.paseo.enable pkgs.paseo
        ++ lib.optional cfg.bb.enable bb
        ++ lib.optional cfg.pomerado.enable pomerado
        ++ lib.optional cfg.amp.enable pkgs.amp-cli
        ++ lib.optional cfg.omp.enable pkgs.omp
        ++ lib.optionals cfg.cua.enable [
          cua.cli
          cua.driver
          cua.spacesd
        ];
      networking.firewall.interfaces.tailscale0.allowedTCPPorts =
        lib.optional cfg.paseo.enable 6767
        ++ lib.optional cfg.bb.enable 38886
        ++ lib.optional cfg.cua.enable 3211;
      systemd.tmpfiles.rules = [
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
        path = [
          pkgs.openssl
          pkgs.tailscale
        ];
        preStart = ''
          set -eu
          mkdir -p "$HOME/.paseo"
          credentials="$HOME/.paseo/server.env"
          if [ ! -s "$credentials" ]; then
            umask 077
            printf 'PASEO_PASSWORD=%s\n' "$(openssl rand -hex 24)" > "$credentials"
          fi
          ip=$(tailscale ip -4 2>/dev/null || true)
          printf 'PASEO_HOSTNAMES=localhost,127.0.0.1,workshop%s\n' "''${ip:+,$ip}" > /run/workshop-paseo/access.env
        '';
        serviceConfig = {
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
        path = [ pkgs.tailscale ];
        preStart = ''
          ip=$(tailscale ip -4 2>/dev/null || true)
          printf 'BB_APP_URL=http://%s:38886\n' "''${ip:-127.0.0.1}" > /run/workshop-bb/access.env
        '';
        serviceConfig = {
          RuntimeDirectory = "workshop-bb";
          RuntimeDirectoryMode = "0700";
          EnvironmentFile = "-/run/workshop-bb/access.env";
          ExecStart = "${bb}/bin/bb-app --no-in-app-updates --server-bind-host 0.0.0.0";
        };
      };
    })
    (lib.mkIf cfg.cua.enable {
      users.users.agent.linger = true;
      services.gnome.at-spi2-core.enable = true;
      systemd.services.workshop-cua-driver = lib.recursiveUpdate service {
        description = "Workshop Cua Driver";
        requires = [ "workshop-display.service" ];
        serviceConfig.ExecStart = "${cua.driver}/bin/cua-driver serve";
      };
      systemd.services.workshop-cua-desktop = lib.recursiveUpdate service {
        description = "Workshop Cua desktop endpoint";
        requires = [ "workshop-display.service" ];
        path = [ pkgs.openssl ];
        preStart = ''
          set -eu
          directory="$HOME/.config/workshop"
          if [ ! -s "$directory/cua-token" ]; then
            umask 077
            openssl rand -hex 32 > "$directory/cua-token"
          fi
        '';
        serviceConfig.ExecStart = "${cua.spacesd}/bin/cua-spacesd serve --listen 0.0.0.0:3211 --quic-port 0 --token-file /home/agent/.config/workshop/cua-token --data-dir /home/agent/.local/state/cua-spacesd";
      };
    })
  ];
}
