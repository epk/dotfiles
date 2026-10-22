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
  browserMcp = pkgs.callPackage ../../../packages/chrome-devtools-mcp.nix { };
  mcpSettings = {
    mcpServers.browser = {
      command = "${browserMcp}/bin/chrome-devtools-mcp";
      args = [
        "--browser-url=http://127.0.0.1:9222"
        "--no-usage-statistics"
        "--no-performance-crux"
      ];
    };
  };
  json = pkgs.formats.json { };
  antigravity = pkgs.callPackage ../../../packages/antigravity-cli.nix { };
  # Each CLI runs directly and keeps its own account and model settings.
  agentTools = [
    pkgs.codex
    pkgs.claude-code
    pkgs.gemini-cli
    antigravity
    pkgs.git
    pkgs.gh
    pkgs.tmux
    pkgs.curl
    pkgs.jq
    pkgs.ripgrep
  ];
  tap = (lib.head config.microvm.interfaces).id;
  user = config.dotfiles.homeUser;
  codexConfig = pkgs.writeText "agent-codex.toml" ''
    approval_policy = "on-request"
    sandbox_mode = "workspace-write"
    cli_auth_credentials_store = "file"
    [mcp_servers.browser]
    command = "${browserMcp}/bin/chrome-devtools-mcp"
    args = ["--browser-url=http://127.0.0.1:9222", "--no-usage-statistics", "--no-performance-crux"]
    [sandbox_workspace_write]
    network_access = true
  '';
  desktopTools = [
    browserMcp
    pkgs.tigervnc
    pkgs.openbox
    pkgs.xterm
    pkgs.chromium
  ];
  desktopService = {
    wantedBy = [ "multi-user.target" ];
    environment = {
      HOME = "/home/agent";
      DISPLAY = ":0";
      XDG_RUNTIME_DIR = "/run/workshop-desktop";
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
  ];
  # The guest is the coding workspace, so its administrator also gets the language toolchains.
  home-manager.users.${user}.imports = [ ../../home/dev.nix ];
  home-manager.users.agent = {
    imports = [ ../../home/dev.nix ];
    home = {
      username = "agent";
      homeDirectory = "/home/agent";
      stateVersion = "26.11";
      sessionVariables.DISPLAY = ":0";
      file.".gemini/config/mcp_config.json".text = builtins.toJSON mcpSettings;
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
    # extraConfig replaces the upstream drive list. Writeback caching passes guest flushes to the host.
    # The host builds the store image from its own store. See modules/nixos/workshop.nix.
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
      AllowUsers = [ user ];
    };
  };
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
  };
  users.groups.agent.gid = 1001;
  security.sudo.wheelNeedsPassword = false;
  # Codex writes trust and notices to ~/.codex/config.toml. It reads this system layer below that file.
  environment.etc."codex/config.toml".source = codexConfig;
  environment.etc."gemini-cli/system-defaults.json".source =
    json.generate "gemini-defaults.json" mcpSettings;
  environment.etc."workshop/mcp.json".source = json.generate "browser-mcp.json" mcpSettings;
  # Claude reads project MCP configuration without restricting other user MCP servers.
  home-manager.users.agent.home.file."workspace/.mcp.json".text = builtins.toJSON mcpSettings;
  services.dbus.enable = true;
  systemd.tmpfiles.rules = [
    "d /home/${user} 0700 ${user} users -"
    "d /home/agent 0700 agent agent -"
    "d /home/agent/workspace 0700 agent agent -"
    "d /home/agent/.codex 0700 agent agent -"
  ];
  systemd.services.workshop-display = lib.recursiveUpdate desktopService {
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
  };
  systemd.services.workshop-window-manager = lib.recursiveUpdate desktopService {
    description = "Workshop window manager";
    requires = [ "workshop-display.service" ];
    after = [ "workshop-display.service" ];
    serviceConfig.ExecStart = "${pkgs.openbox}/bin/openbox";
  };
  systemd.services.workshop-browser = lib.recursiveUpdate desktopService {
    description = "Workshop Chromium browser";
    requires = [ "workshop-display.service" ];
    after = [
      "workshop-display.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    serviceConfig.ExecStart = "${pkgs.chromium}/bin/chromium --ozone-platform=x11 --user-data-dir=/home/agent/.config/chromium --remote-debugging-address=127.0.0.1 --remote-debugging-port=9222 --no-first-run --no-default-browser-check about:blank";
  };
  environment.systemPackages = agentTools ++ desktopTools;
  fonts.packages = [
    pkgs.dejavu_fonts
    pkgs.noto-fonts-color-emoji
  ];
  services.journald.settings.Journal.SystemMaxUse = "128M";
  time.timeZone = "UTC";
}
