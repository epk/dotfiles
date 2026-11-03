# Inside the workshop VM: users, agent CLIs, MCP servers and the desktop. modules/nixos/workshop/host.nix boots it.
{
  config,
  lib,
  inputs,
  pkgs,
  workshop,
  ...
}:
let
  inherit (workshop) network tools;
  disk = image: mountPoint: size: {
    image = "${workshop.storageDirectory}/${image}.raw";
    inherit mountPoint size;
    imageType = "raw";
    fsType = "ext4";
    direct = false;
    autoCreate = false;
  };
  desktopEnabled = tools.browser.enable || tools.cua.enable || tools.pomerado.enable;
  mcpServers =
    lib.optionalAttrs tools.browser.enable {
      browser = {
        command = "${pkgs.chrome-devtools-mcp}/bin/chrome-devtools-mcp";
        args = [
          "--browser-url=http://127.0.0.1:9222"
          "--no-usage-statistics"
          "--no-performance-crux"
        ];
      };
    }
    // lib.optionalAttrs tools.cua.enable {
      cua = {
        command = "${pkgs.cua-driver}/bin/cua-driver";
        args = [ "mcp" ];
      };
    }
    // lib.optionalAttrs tools.pomerado.enable {
      pomerado = {
        command = "${pkgs.pomerado}/bin/pomerado-mcp";
        args = [
          "mint"
          "--root"
          "/home/agent/integrations"
          "--headed"
        ];
      };
    };
  json = pkgs.formats.json { };
  mcpJson = json.generate "workshop-mcp.json" { inherit mcpServers; };
  ampSettings = pkgs.writers.writePython3Bin "workshop-amp-settings" { } (
    builtins.readFile ./amp-settings.py
  );
  # Each CLI runs directly and keeps its own account and model settings.
  agentTools =
    lib.optional tools.codex.enable pkgs.codex
    ++ lib.optional tools.claudeCode.enable pkgs.claude-code
    ++ lib.optional tools.gemini.enable pkgs.gemini-cli
    ++ lib.optional tools.antigravity.enable pkgs.antigravity-cli
    ++ [
      pkgs.git
      pkgs.gh
      pkgs.tmux
      pkgs.curl
      pkgs.jq
      pkgs.ripgrep
      pkgs.bubblewrap
    ];
  user = config.dotfiles.homeUser;
  agent = config.users.users.agent;
  agentHome = config.home-manager.users.agent.programs;
  desktopTools =
    lib.optionals desktopEnabled [
      pkgs.tigervnc
      pkgs.openbox
      pkgs.xterm
    ]
    ++ lib.optionals tools.browser.enable [
      pkgs.chrome-devtools-mcp
      pkgs.chromium
    ];
  agentUnit = {
    wantedBy = [ "multi-user.target" ];
    environment = {
      HOME = agent.home;
      DISPLAY = ":0";
      XDG_RUNTIME_DIR = "/run/user/${toString agent.uid}";
      DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/${toString agent.uid}/bus";
    };
    serviceConfig = {
      User = "agent";
      Group = "agent";
      UMask = "0077";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };
  agentPath = "/etc/profiles/per-user/agent/bin:/run/current-system/sw/bin";
in
{
  imports = [
    ../base.nix
    ../home.nix
    ./tools.nix
    inputs.determinate.nixosModules.default
  ];
  _module.args = { inherit agentUnit agentPath; };
  # The guest is the coding workspace, so its administrator also gets the language toolchains.
  home-manager.users.${user}.imports = [ ../../home/dev.nix ];
  home-manager.users.agent = {
    imports = [ ../../home/dev.nix ];
    home = {
      username = "agent";
      homeDirectory = agent.home;
      stateVersion = "26.11";
      sessionVariables.DISPLAY = ":0";
      file.".omp/agent/mcp.json" = lib.mkIf tools.omp.enable { source = mcpJson; };
      # Amp also writes model preferences here. Keep those settings writable.
      activation.workshopAmpSettings = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ${ampSettings}/bin/workshop-amp-settings ${
          json.generate "workshop-amp-tools.json" {
            enabled = tools.amp.enable;
            servers = mcpServers;
          }
        }
      '';
    };
    programs.bash.enable = true;
    programs.mcp = {
      enable = true;
      servers = mcpServers;
    };
    programs.claude-code = lib.mkIf tools.claudeCode.enable {
      enable = true;
      enableMcpIntegration = true;
    };
    programs.codex = lib.mkIf tools.codex.enable {
      enable = true;
      enableMcpIntegration = true;
      # Codex writes trust and notices to its config file.
      mutableSettings = true;
      settings = {
        approval_policy = "never";
        sandbox_mode = "danger-full-access";
        cli_auth_credentials_store = "file";
        sandbox_workspace_write.network_access = true;
        # The nixpkgs build disabled this feature. See openai/codex issue 48195.
        features.daemon_auto_start = false;
        mcp_servers = lib.optionalAttrs tools.pomerado.enable {
          pomerado = mcpServers.pomerado // {
            env_vars = [ "OPENAI_API_KEY" ];
          };
        };
      };
    };
    programs.antigravity-cli = lib.mkIf tools.antigravity.enable {
      enable = true;
      enableMcpIntegration = true;
    };
  };
  nixpkgs.overlays = [
    inputs.rust-overlay.overlays.default
    inputs.self.overlays.default
  ];
  # nixpkgs plans to remove Gemini CLI. Keep it for API-key access until then.
  nixpkgs.config.problems.handlers.gemini-cli.removal = "ignore";
  nixpkgs.config.allowUnfreePredicate =
    package:
    builtins.elem (lib.getName package) [
      "claude-code"
      "antigravity-cli"
      "amp-cli"
      "cua-spacesd"
      "cua-cli"
    ];
  networking = {
    hostName = "workshop";
    useDHCP = false;
    enableIPv6 = false;
    usePredictableInterfaceNames = false;
    nameservers = (import ../../../lib/network.nix).guestNameservers;
    interfaces.eth0.ipv4.addresses = [
      {
        address = network.guestAddress;
        inherit (network) prefixLength;
      }
    ];
    defaultGateway = {
      address = network.hostAddress;
      interface = "eth0";
    };
  };
  services.openssh = {
    hostKeys = [
      {
        path = "/var/lib/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings.AllowUsers = [ user ];
  };
  # The pinned Firecracker release does not support guest discard.
  services.fstrim.enable = false;
  microvm = {
    hypervisor = "firecracker";
    balloon = false;
    shares = [ ];
    vcpu = 2;
    mem = 4096;
    # Keep the base image read-only. Guest builds write only to its private home disk.
    writableStoreOverlay = "/home/.nix-store";
    interfaces = [
      {
        type = "tap";
        id = network.interface;
        mac = "02:00:00:00:77:02";
      }
    ];
    volumes = [
      (disk "state" "/var" 8192)
      (disk "home" "/home" 32768)
    ];
    # Upstream gives the TAP device to the user microvm. This VM runs as its own host user.
    binScripts.tap-up = lib.mkForce ''
      set -eu
      # A crashed VM can leave its TAP device behind.
      ${pkgs.iproute2}/bin/ip link delete ${network.interface} 2>/dev/null || true
      ${pkgs.iproute2}/bin/ip tuntap add dev ${network.interface} mode tap user vm-${config.networking.hostName}
      ${pkgs.iproute2}/bin/ip link set ${network.interface} up
    '';
    # extraConfig replaces the upstream drive list. Writeback caching passes guest flushes to the host.
    # The host builds the store image from its own store. See modules/nixos/workshop/host.nix.
    firecracker.extraConfig.drives = [
      {
        drive_id = "store";
        path_on_host = "${workshop.storageDirectory}/store.erofs";
        is_root_device = false;
        is_read_only = true;
        io_engine = "Sync";
      }
    ]
    ++ map (volume: {
      drive_id = lib.removeSuffix ".raw" (baseNameOf volume.image);
      path_on_host = volume.image;
      is_root_device = false;
      is_read_only = volume.readOnly;
      io_engine = "Sync";
      cache_type = "Writeback";
    }) config.microvm.volumes;
  };
  # The private state disk preserves this guest's Tailscale registration across rebuilds.
  services.tailscale = {
    enable = true;
    openFirewall = true;
    disableTaildrop = true;
    extraSetFlags = [
      "--hostname=workshop"
      "--ssh"
      "--accept-dns=false"
      "--accept-routes=false"
    ];
  };
  networking.nftables = {
    enable = true;
    flushRuleset = false;
  };
  systemd.services.tailscaled.environment.TS_DEBUG_FIREWALL_MODE = "nftables";
  networking.firewall.allowedTCPPorts = [ 22 ];
  fileSystems."/home".neededForBoot = true;
  users.users.${user} = {
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
    # The agent units use the user runtime directory and session bus.
    linger = true;
  };
  users.groups.agent.gid = 1001;
  environment.etc."gemini-cli/system-defaults.json" = lib.mkIf tools.gemini.enable {
    source = mcpJson;
  };
  environment.etc."workshop/mcp.json".source = mcpJson;
  services.dbus.enable = true;
  systemd.tmpfiles.rules = [
    "d /home/${user} 0700 ${user} users -"
    "d /home/agent 0700 agent agent -"
    "d /home/agent/workspace 0700 agent agent -"
    "d /home/agent/.codex 0700 agent agent -"
  ];
  systemd.services.workshop-display = lib.mkIf desktopEnabled (
    lib.recursiveUpdate agentUnit {
      description = "Workshop virtual desktop";
      path = [ pkgs.xdpyinfo ];
      serviceConfig = {
        RuntimeDirectory = "workshop-desktop";
        RuntimeDirectoryMode = "0700";
        ExecStart = "${pkgs.tigervnc}/bin/Xvnc :0 -geometry 1440x900 -depth 24 -localhost -SecurityTypes None -nolisten tcp";
      };
      postStart = ''
        for attempt in $(seq 1 50); do
          if xdpyinfo >/dev/null 2>&1; then exit 0; fi
          sleep 0.2
        done
        exit 1
      '';
    }
  );
  systemd.services.workshop-window-manager = lib.mkIf desktopEnabled (
    lib.recursiveUpdate agentUnit {
      description = "Workshop window manager";
      requires = [ "workshop-display.service" ];
      after = [ "workshop-display.service" ];
      serviceConfig.ExecStart = "${pkgs.openbox}/bin/openbox";
    }
  );
  systemd.services.workshop-browser = lib.mkIf tools.browser.enable (
    lib.recursiveUpdate agentUnit {
      description = "Workshop Chromium browser";
      requires = [ "workshop-display.service" ];
      after = [
        "workshop-display.service"
        "network-online.target"
      ];
      wants = [ "network-online.target" ];
      serviceConfig.ExecStart = "${pkgs.chromium}/bin/chromium --ozone-platform=x11 --user-data-dir=/home/agent/.config/chromium --remote-debugging-address=127.0.0.1 --remote-debugging-port=9222 --no-first-run --no-default-browser-check about:blank";
    }
  );
  systemd.services.workshop-claude-remote = lib.mkIf tools.claudeCode.enable (
    lib.recursiveUpdate agentUnit {
      description = "Workshop Claude Code remote access";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      unitConfig.ConditionPathExists = "/home/agent/.claude/.credentials.json";
      environment.PATH = lib.mkForce agentPath;
      serviceConfig = {
        WorkingDirectory = "/home/agent/workspace";
        ExecStart = "${agentHome.claude-code.finalPackage}/bin/claude remote-control --name Workshop --capacity 4 --permission-mode bypassPermissions";
        Restart = "always";
        RestartSec = 15;
      };
    }
  );
  systemd.services.workshop-codex-remote = lib.mkIf tools.codex.enable (
    lib.recursiveUpdate agentUnit {
      description = "Workshop Codex remote access";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      unitConfig.ConditionPathExists = "/home/agent/.codex/auth.json";
      environment.PATH = lib.mkForce agentPath;
      serviceConfig = {
        WorkingDirectory = "/home/agent/workspace";
        # Keep the native control socket available for device pairing. Nix supplies the pinned binary.
        ExecStart = "${agentHome.codex.package}/bin/codex app-server --remote-control --listen unix:// --managed-daemon";
        Restart = "always";
        RestartSec = 15;
      };
    }
  );
  environment.systemPackages = agentTools ++ desktopTools;
  fonts.packages = [
    pkgs.dejavu_fonts
    pkgs.noto-fonts-color-emoji
  ];
  services.journald.settings.Journal.SystemMaxUse = "128M";
}
