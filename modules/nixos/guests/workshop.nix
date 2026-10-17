{
  config,
  lib,
  pkgs,
  workshop,
  ...
}:
let
  disk = image: mountPoint: size: {
    image = "${workshop.storageDirectory}/${image}.raw";
    inherit mountPoint size;
    imageType = "raw";
    fsType = "ext4";
    direct = false;
    autoCreate = false;
  };
  inherit (pkgs) paseo;
  sharedBrowser = pkgs.callPackage ../../../packages/shared-browser.nix { };
  antigravity = pkgs.callPackage ../../../packages/antigravity-cli.nix { };
  # Paseo starts agents with the service PATH. Give them the same tools as a shell.
  agentTools = [
    pkgs.codex
    pkgs.claude-code
    pkgs.gemini-cli
    antigravity
    pkgs.git
    pkgs.gh
    pkgs.nodejs_24
    pkgs.python3
    pkgs.tmux
    pkgs.curl
    pkgs.jq
    pkgs.ripgrep
  ];
  tap = (lib.head config.microvm.interfaces).id;
  codexConfig = pkgs.writeText "agent-codex.toml" ''
    approval_policy = "on-request"
    sandbox_mode = "workspace-write"
    cli_auth_credentials_store = "file"
    [sandbox_workspace_write]
    network_access = true
  '';
  paseoConfig = (pkgs.formats.json { }).generate "agent-paseo.json" {
    daemon = {
      listen = "127.0.0.1:6767";
      relay.enabled = false;
      browserTools.enabled = false;
    };
    features = {
      webUi.enabled = true;
      voiceMode.enabled = false;
      dictation.enabled = false;
    };
    pluginsEnabled = true;
    agents.providers = {
      gemini = {
        extends = "acp";
        label = "Gemini CLI";
        enabled = false;
        command = [
          "${pkgs.gemini-cli}/bin/gemini"
          "--acp"
        ];
      };
      antigravity = {
        enabled = true;
        command = [ "${antigravity}/bin/agy" ];
      };
      claude.env = {
        DISABLE_NONESSENTIAL_TRAFFIC = "1";
        FORCE_AUTOUPDATE_PLUGINS = "0";
      };
    };
    plugins.shared-browser = {
      source = "directory";
      path = "${sharedBrowser}/plugin";
      enabled = true;
    };
    log.file.rotate = {
      maxSize = "10M";
      maxFiles = 3;
    };
  };
in
{
  imports = [ ../microvm-guest.nix ];
  # nixpkgs plans to remove Gemini CLI. Keep it for API-key access until then.
  nixpkgs.config.problems.handlers.gemini-cli.removal = "ignore";
  nixpkgs.config.allowUnfreePredicate =
    package:
    builtins.elem (lib.getName package) [
      "claude-code"
      "antigravity-cli"
    ];
  networking.hostName = "workshop";
  networking.useDHCP = false;
  networking.enableIPv6 = false;
  networking.usePredictableInterfaceNames = false;
  networking.interfaces.eth0.ipv4.addresses = [
    {
      address = "10.77.0.2";
      prefixLength = 30;
    }
  ];
  networking.defaultGateway = {
    address = "10.77.0.1";
    interface = "eth0";
  };
  networking.nameservers = [
    "1.1.1.1"
    "9.9.9.9"
  ];
  microvm = {
    hypervisor = "firecracker";
    vcpu = 2;
    mem = 4096;
    balloon = false;
    shares = [ ];
    interfaces = [
      {
        type = "tap";
        id = "workshop-tap";
        mac = "02:00:00:00:77:02";
      }
    ];
    volumes = [
      (disk "state" "/var" 8192)
      (disk "home" "/home" 32768)
    ];
    # extraConfig replaces the upstream drive list. Writeback caching passes guest flushes to the host.
    firecracker.extraConfig.drives = [
      {
        drive_id = "store";
        path_on_host = config.microvm.storeDisk;
        is_root_device = false;
        is_read_only = true;
        io_engine = "Sync";
      }
    ]
    ++ map (volume: {
      drive_id = lib.removeSuffix ".raw" (baseNameOf volume.image);
      path_on_host = volume.image;
      is_root_device = false;
      is_read_only = false;
      io_engine = "Sync";
      cache_type = "Writeback";
    }) config.microvm.volumes;
    # Upstream gives the TAP device to the user microvm. This VM runs as its own host user.
    binScripts.tap-up = lib.mkForce ''
      set -eu
      # A crashed VM can leave its TAP device behind.
      ${pkgs.iproute2}/bin/ip link delete ${tap} 2>/dev/null || true
      ${pkgs.iproute2}/bin/ip tuntap add dev ${tap} mode tap user vm-${config.networking.hostName}
      ${pkgs.iproute2}/bin/ip link set ${tap} up
    '';
  };
  # The pinned Firecracker release does not support guest discard.
  services.fstrim.enable = false;
  services.openssh = {
    enable = true;
    hostKeys = [
      {
        path = "/var/lib/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "operator" ];
    };
  };
  networking.firewall.allowedTCPPorts = [ 22 ];
  fileSystems."/home".neededForBoot = true;
  users.users.operator = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = workshop.administratorKeys;
    uid = 1000;
    extraGroups = [ "wheel" ];
  };
  users.users.agent = {
    isNormalUser = true;
    uid = 1001;
    group = "agent";
    home = "/home/agent";
  };
  users.groups.agent.gid = 1001;
  security.sudo.wheelNeedsPassword = false;
  systemd.tmpfiles.rules = [
    "d /home/operator 0700 operator users -"
    "d /home/agent 0700 agent agent -"
    "d /home/agent/workspace 0700 agent agent -"
    "d /home/agent/.codex 0700 agent agent -"
    "L+ /home/agent/.codex/config.toml - agent agent - ${codexConfig}"
    "d /home/agent/.paseo 0700 agent agent -"
    "d /home/agent/.paseo/plugin-data 0700 agent agent -"
    "d /home/agent/.paseo/plugin-data/shared-browser 0700 agent agent -"
    "L+ /home/agent/.paseo/plugin-data/shared-browser/runtime - agent agent - ${sharedBrowser}/runtime"
  ];
  systemd.services.paseo = {
    description = "Private agent control and shared browser";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = agentTools ++ [
      pkgs.openssh
      pkgs.bashInteractive
      pkgs.procps
    ];
    environment = {
      HOME = "/home/agent";
      PASEO_HOME = "/home/agent/.paseo";
      PASEO_LISTEN = "127.0.0.1:6767";
      PASEO_WEB_UI_ENABLED = "true";
      PASEO_SHARED_BROWSER_CHROMIUM_EXECUTABLE = "${pkgs.chromium}/bin/chromium";
      PASEO_SHARED_BROWSER_AGENT_BROWSER_BINARY = "${pkgs.agent-browser}/bin/agent-browser";
      PASEO_SHARED_BROWSER_XVFB = "1";
    };
    preStart = ''
      install -m 0600 ${paseoConfig} /home/agent/.paseo/config.json
    '';
    serviceConfig = {
      User = "agent";
      Group = "agent";
      WorkingDirectory = "/home/agent/workspace";
      ExecStart = "${paseo}/bin/paseo-server --no-relay";
      Restart = "on-failure";
      RestartSec = 5;
      UMask = "0077";
      RuntimeDirectory = "paseo";
      Environment = "XDG_RUNTIME_DIR=/run/paseo";
      PrivateTmp = true;
      ProtectSystem = "strict";
      ReadWritePaths = [
        "/home/agent"
        "/run/paseo"
      ];
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      NoNewPrivileges = true;
      CapabilityBoundingSet = "";
    };
  };
  environment.systemPackages = agentTools ++ [
    paseo
    pkgs.chromium
  ];
  fonts.packages = [
    pkgs.dejavu_fonts
    pkgs.noto-fonts-color-emoji
  ];
  services.journald.settings.Journal.SystemMaxUse = "128M";
  time.timeZone = "UTC";
}
