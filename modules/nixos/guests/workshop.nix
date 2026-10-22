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
  waymote = pkgs.callPackage ../../../packages/waymote.nix { };
  antigravity = pkgs.callPackage ../../../packages/antigravity-cli.nix { };
  # The runner and its child agents use the same tools as a shell.
  agentTools = [
    pkgs.amp-cli
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
  user = config.dotfiles.homeUser;
  codexConfig = pkgs.writeText "agent-codex.toml" ''
    approval_policy = "on-request"
    sandbox_mode = "workspace-write"
    cli_auth_credentials_store = "file"
    [sandbox_workspace_write]
    network_access = true
  '';
  desktopTools = [
    waymote
    pkgs.labwc
    pkgs.wlr-randr
    pkgs.ffmpeg
    pkgs.xwayland
    pkgs.wl-clipboard
    pkgs.dbus
    pkgs.pulseaudio
    pkgs.chromium
  ];
  ampSettings = (pkgs.formats.json { }).generate "amp-managed-settings.json" {
    "amp.updates.mode" = "disabled";
    "amp.runner.autoUpdate.enabled" = false;
    "amp.runner.env.enabled" = false;
  };
in
{
  imports = [
    ../microvm-guest.nix
    ../home.nix
  ];
  # The guest is the coding workspace, so its administrator also gets the language toolchains.
  home-manager.users.${user}.imports = [ ../../home/dev.nix ];
  nixpkgs.overlays = [ inputs.rust-overlay.overlays.default ];
  # nixpkgs plans to remove Gemini CLI. Keep it for API-key access until then.
  nixpkgs.config.problems.handlers.gemini-cli.removal = "ignore";
  nixpkgs.config.allowUnfreePredicate =
    package:
    builtins.elem (lib.getName package) [
      "amp-cli"
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
  environment.etc."ampcode/managed-settings.json".source = ampSettings;
  services.dbus.enable = true;
  systemd.tmpfiles.rules = [
    "d /home/${user} 0700 ${user} users -"
    "d /home/agent 0700 agent agent -"
    "d /home/agent/workspace 0700 agent agent -"
    "d /home/agent/.codex 0700 agent agent -"
    "d /home/agent/.config/amp 0700 agent agent -"
    "d /home/agent/.local/share/amp 0700 agent agent -"
  ];
  # Login stores the account in the persistent home. No credential enters the Nix store.
  systemd.paths.amp-runner = {
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathExists = "/home/agent/.local/share/amp/secrets.json";
      Unit = "amp-runner.service";
    };
  };
  systemd.services.amp-runner = {
    description = "Amp coding runner and desktop";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "/home/agent/.local/share/amp/secrets.json";
    path =
      agentTools
      ++ desktopTools
      ++ [
        pkgs.openssh
        pkgs.bashInteractive
        pkgs.procps
      ];
    environment = {
      HOME = "/home/agent";
      XDG_RUNTIME_DIR = "/run/amp-runner";
      NIXOS_OZONE_WL = "1";
      DISABLE_NONESSENTIAL_TRAFFIC = "1";
      FORCE_AUTOUPDATE_PLUGINS = "0";
    };
    restartTriggers = [ ampSettings ];
    serviceConfig = {
      User = "agent";
      Group = "agent";
      WorkingDirectory = "/home/agent/workspace";
      ExecStart = "${pkgs.amp-cli}/bin/amp --no-tui --runner-id workshop --desktop --remote-control-terminal";
      Restart = "on-failure";
      RestartSec = 30;
      UMask = "0077";
      RuntimeDirectory = "amp-runner";
      RuntimeDirectoryMode = "0700";
      PrivateTmp = true;
      ProtectSystem = "strict";
      ReadWritePaths = [
        "/home/agent"
        "/run/amp-runner"
      ];
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      NoNewPrivileges = true;
      CapabilityBoundingSet = "";
    };
  };
  environment.systemPackages = agentTools ++ desktopTools;
  fonts.packages = [
    pkgs.dejavu_fonts
    pkgs.noto-fonts-color-emoji
  ];
  services.journald.settings.Journal.SystemMaxUse = "128M";
  time.timeZone = "UTC";
}
