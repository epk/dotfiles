{
  config,
  lib,
  inputs,
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
  tools = config.services.workshopTools;
  desktopEnabled = tools.browser.enable || tools.cua.enable;
  cua = pkgs.callPackage ../../../packages/cua.nix { };
  pomerado = pkgs.callPackage ../../../packages/pomerado { };
  browserMcp = pkgs.callPackage ../../../packages/chrome-devtools-mcp.nix { };
  mcpServers =
    lib.optionalAttrs tools.browser.enable {
      browser = {
        command = "${browserMcp}/bin/chrome-devtools-mcp";
        args = [
          "--browser-url=http://127.0.0.1:9222"
          "--no-usage-statistics"
          "--no-performance-crux"
        ];
      };
    }
    // lib.optionalAttrs tools.cua.enable {
      cua = {
        command = "${cua.driver}/bin/cua-driver";
        args = [ "mcp" ];
      };
    }
    // lib.optionalAttrs tools.pomerado.enable {
      pomerado = {
        command = "${pomerado}/bin/pomerado-mcp";
        args = [
          "mint"
          "--root"
          "/home/agent/integrations"
          "--headed"
        ];
      };
    };
  mcpSettings = { inherit mcpServers; };
  json = pkgs.formats.json { };
  antigravity = pkgs.callPackage ../../../packages/antigravity-cli.nix { };
  # Each CLI runs directly and keeps its own account and model settings.
  agentTools =
    lib.optional tools.codex.enable pkgs.codex
    ++ lib.optional tools.claudeCode.enable pkgs.claude-code
    ++ lib.optional tools.gemini.enable pkgs.gemini-cli
    ++ lib.optional tools.antigravity.enable antigravity
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
  codexConfig = pkgs.writeText "agent-codex.toml" ''
    approval_policy = "never"
    sandbox_mode = "danger-full-access"
    cli_auth_credentials_store = "file"
    ${lib.concatMapStringsSep "\n" (
      name:
      let
        server = mcpServers.${name};
      in
      ''
        [mcp_servers.${name}]
        command = ${builtins.toJSON server.command}
        args = ${builtins.toJSON server.args}
        ${lib.optionalString (name == "pomerado") ''env_vars = ["OPENAI_API_KEY"]''}
      ''
    ) (builtins.attrNames mcpServers)}
    [sandbox_workspace_write]
    network_access = true
  '';
  desktopTools =
    lib.optionals desktopEnabled [
      pkgs.tigervnc
      pkgs.openbox
      pkgs.xterm
    ]
    ++ lib.optionals tools.browser.enable [
      browserMcp
      pkgs.chromium
    ];
  desktopService = {
    wantedBy = [ "multi-user.target" ];
    environment = {
      HOME = "/home/agent";
      DISPLAY = ":0";
      XDG_RUNTIME_DIR = "/run/user/1001";
      DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/1001/bus";
    };
    serviceConfig = {
      User = "agent";
      Group = "agent";
      UMask = "0077";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };

in
{
  imports = [
    ../microvm-guest.nix
    ../home.nix
    ./workshop-tools.nix
  ];
  services.workshopTools =
    workshop.tools or {
      browser.enable = true;
      claudeCode.enable = true;
      codex.enable = true;
      gemini.enable = true;
      antigravity.enable = true;
    };
  # The guest is the coding workspace, so its administrator also gets the language toolchains.
  home-manager.users.${user}.imports = [ ../../home/dev.nix ];
  home-manager.users.agent = {
    imports = [ ../../home/dev.nix ];
    home = {
      username = "agent";
      homeDirectory = "/home/agent";
      stateVersion = "26.11";
      sessionVariables.DISPLAY = ":0";
      file.".gemini/config/mcp_config.json" = lib.mkIf tools.antigravity.enable {
        text = builtins.toJSON mcpSettings;
      };
    };
    programs.bash.enable = true;
  };
  nixpkgs.overlays = [ inputs.rust-overlay.overlays.default ];
  # nixpkgs plans to remove Gemini CLI. Keep it for API-key access until then.
  nixpkgs.config.problems.handlers.gemini-cli.removal = "ignore";
  nixpkgs.config.allowUnfreePredicate =
    package:
    builtins.elem (lib.getName package) [
      "claude-code"
      "antigravity-cli"
      "amp-cli"
      "cua-spacesd"
    ];
  networking.hostName = "workshop";
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
  # The host builds the store image from its own store. See modules/nixos/workshop.nix.
  dotfiles.guestStoreImage = "${workshop.storageDirectory}/store.erofs";
  microvm = {
    vcpu = 2;
    mem = 4096;
    # Keep the base image read-only. Guest builds write only to its private home disk.
    writableStoreOverlay = "/home/.nix-store";
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
    linger = desktopEnabled;
  };
  users.groups.agent.gid = 1001;
  # Codex writes trust and notices to ~/.codex/config.toml. It reads this system layer below that file.
  environment.etc."codex/config.toml" = lib.mkIf tools.codex.enable { source = codexConfig; };
  environment.etc."gemini-cli/system-defaults.json" = lib.mkIf tools.gemini.enable {
    source = json.generate "gemini-defaults.json" mcpSettings;
  };
  environment.etc."workshop/mcp.json".source = json.generate "browser-mcp.json" mcpSettings;
  # Claude reads project MCP configuration without restricting other user MCP servers.
  home-manager.users.agent.home.file."workspace/.mcp.json" = lib.mkIf tools.claudeCode.enable {
    text = builtins.toJSON mcpSettings;
  };
  home-manager.users.agent.home.file.".omp/agent/mcp.json" = lib.mkIf tools.omp.enable {
    text = builtins.toJSON mcpSettings;
  };
  home-manager.users.agent.home.file.".config/amp/settings.json" = lib.mkIf tools.amp.enable {
    text = builtins.toJSON { "amp.mcpServers" = mcpServers; };
  };
  services.dbus.enable = true;
  systemd.tmpfiles.rules = [
    "d /home/${user} 0700 ${user} users -"
    "d /home/agent 0700 agent agent -"
    "d /home/agent/workspace 0700 agent agent -"
    "d /home/agent/.codex 0700 agent agent -"
  ];
  systemd.services.workshop-display = lib.mkIf desktopEnabled (
    lib.recursiveUpdate desktopService {
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
    lib.recursiveUpdate desktopService {
      description = "Workshop window manager";
      requires = [ "workshop-display.service" ];
      after = [ "workshop-display.service" ];
      serviceConfig.ExecStart = "${pkgs.openbox}/bin/openbox";
    }
  );
  systemd.services.workshop-browser = lib.mkIf tools.browser.enable (
    lib.recursiveUpdate desktopService {
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
    lib.recursiveUpdate desktopService {
      description = "Workshop Claude Code remote access";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      unitConfig.ConditionPathExists = "/home/agent/.claude/.credentials.json";
      environment.PATH = lib.mkForce "/etc/profiles/per-user/agent/bin:/run/current-system/sw/bin";
      serviceConfig = {
        WorkingDirectory = "/home/agent/workspace";
        ExecStart = "${pkgs.claude-code}/bin/claude remote-control --name Workshop --capacity 4 --permission-mode bypassPermissions";
        Restart = "always";
        RestartSec = 15;
      };
    }
  );
  systemd.services.workshop-codex-remote = lib.mkIf tools.codex.enable (
    lib.recursiveUpdate desktopService {
      description = "Workshop Codex remote access";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      unitConfig.ConditionPathExists = "/home/agent/.codex/auth.json";
      environment.PATH = lib.mkForce "/etc/profiles/per-user/agent/bin:/run/current-system/sw/bin";
      serviceConfig = {
        WorkingDirectory = "/home/agent/workspace";
        # Keep the native control socket available for device pairing. Nix supplies the pinned binary.
        ExecStart = "${pkgs.codex}/bin/codex app-server --remote-control --listen unix:// --managed-daemon";
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
