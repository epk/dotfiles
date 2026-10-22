{
  config,
  lib,
  pkgs,
  vpn,
  ...
}:
let
  user = (import ../../../lib/user.nix).username;
  tunnelPrefix = "10.199.29";
  tunnelSubnet = "${tunnelPrefix}.0/24";
  tunnelAddress = "${tunnelPrefix}.1/24";
  portal = pkgs.callPackage ../../../packages/wg-portal.nix { };
  settings = (pkgs.formats.yaml { }).generate "wg-portal.yaml" {
    core = {
      admin_user = "admin@localhost";
      import_existing = true;
      restore_state = true;
    };
    advanced = {
      use_ip_v6 = false;
      start_listen_port = 51820;
      start_cidr_v4 = tunnelSubnet;
      config_storage_path = "/var/lib/wg-portal/configs";
    };
    database = {
      type = "sqlite";
      dsn = "/var/lib/wg-portal/portal.db";
    };
    statistics = {
      listening_address = "127.0.0.1:8787";
      use_ping_checks = false;
    };
    web = {
      listening_address = "10.78.0.2:8888";
      expose_host_info = false;
    };
  };
in
{
  imports = [ ../microvm-guest.nix ];
  networking = {
    hostName = "vpn";
    useDHCP = false;
    enableIPv6 = false;
    usePredictableInterfaceNames = false;
    interfaces.eth0.ipv4.addresses = [
      {
        address = "10.78.0.2";
        prefixLength = 30;
      }
    ];
    defaultGateway = {
      address = "10.78.0.1";
      interface = "eth0";
    };
    nameservers = [
      "1.1.1.1"
      "9.9.9.9"
    ];
    firewall = {
      checkReversePath = "loose";
      interfaces.eth0.allowedUDPPorts = [ 51820 ];
      extraInputRules = ''
        iifname "eth0" ip saddr 10.78.0.1 tcp dport { 22, 8888 } accept
      '';
    };
    nftables = {
      enable = true;
      tables.vpn = {
        family = "inet";
        content = ''
          set non_public_v4 {
            type ipv4_addr
            flags interval
            elements = {
              0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8,
              169.254.0.0/16, 172.16.0.0/12, 192.0.0.0/24, 192.0.2.0/24,
              192.168.0.0/16, 198.18.0.0/15, 198.51.100.0/24, 203.0.113.0/24,
              224.0.0.0/4, 240.0.0.0/4
            }
          }
          chain forward {
            type filter hook forward priority -10; policy drop;
            ct state invalid drop
            iifname "wg_in" oifname "eth0" ip saddr ${tunnelSubnet} ip daddr != @non_public_v4 accept
            iifname "eth0" oifname "wg_in" ip daddr ${tunnelSubnet} ct state { established, related } accept
          }
        '';
      };
      tables.vpn-nat = {
        family = "ip";
        content = ''
          chain postrouting {
            type nat hook postrouting priority srcnat; policy accept;
            iifname "wg_in" oifname "eth0" ip saddr ${tunnelSubnet} masquerade
          }
        '';
      };
    };
  };
  boot.kernelModules = [ "wireguard" ];
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  microvm = {
    hypervisor = "firecracker";
    vcpu = 1;
    mem = 512;
    balloon = false;
    shares = [ ];
    interfaces = [
      {
        type = "tap";
        id = "vpn-tap";
        mac = "02:00:00:00:78:02";
      }
    ];
    volumes = [
      {
        image = "${vpn.storageDirectory}/state.raw";
        mountPoint = "/var";
        size = 4096;
        imageType = "raw";
        fsType = "ext4";
        direct = false;
        autoCreate = false;
      }
      {
        image = "${vpn.storageDirectory}/host-config.raw";
        mountPoint = "/run/host-config";
        size = 8;
        imageType = "raw";
        fsType = "ext4";
        readOnly = true;
        autoCreate = false;
        direct = false;
      }
    ];
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
      is_read_only = volume.readOnly;
      io_engine = "Sync";
      cache_type = "Writeback";
    }) config.microvm.volumes;
    binScripts.tap-up = lib.mkForce ''
      set -eu
      ${pkgs.iproute2}/bin/ip link delete vpn-tap 2>/dev/null || true
      ${pkgs.iproute2}/bin/ip tuntap add dev vpn-tap mode tap user vm-vpn
      ${pkgs.iproute2}/bin/ip link set vpn-tap up
    '';
  };
  # Deploy the complete system image. This appliance does not build or activate Nix profiles.
  nix.enable = false;
  fileSystems."/run/host-config" = {
    options = [
      "ro"
      "noload"
      "nodev"
      "nosuid"
      "noexec"
    ];
    noCheck = true;
  };
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
  users.users.${user} = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = vpn.administratorKeys;
    extraGroups = [ "wheel" ];
  };
  security.sudo.wheelNeedsPassword = false;
  users.users.wg-portal = {
    isSystemUser = true;
    group = "wg-portal";
  };
  users.groups.wg-portal = { };
  systemd.services.vpn-credentials = {
    description = "Create persistent VPN credentials";
    before = [
      "vpn-interface.service"
      "wg-portal.service"
    ];
    requiredBy = [
      "vpn-interface.service"
      "wg-portal.service"
    ];
    path = [
      pkgs.openssl
      pkgs.wireguard-tools
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0077";
    };
    script = ''
      set -eu
      install -d -m 0700 -o wg-portal -g wg-portal /var/lib/wg-portal
      if [ ! -s /var/lib/wg-portal/wireguard.key ]; then
        wg genkey > /var/lib/wg-portal/wireguard.key.new
        mv /var/lib/wg-portal/wireguard.key.new /var/lib/wg-portal/wireguard.key
      fi
      if [ ! -s /var/lib/wg-portal/secrets.env ]; then
        for name in CORE_ADMIN_PASSWORD CORE_ADMIN_API_TOKEN WEB_SESSION_SECRET WEB_CSRF_SECRET DATABASE_ENCRYPTION_PASSPHRASE; do
          printf 'WG_PORTAL_%s=%s\n' "$name" "$(openssl rand -hex 32)"
        done > /var/lib/wg-portal/secrets.env.new
        mv /var/lib/wg-portal/secrets.env.new /var/lib/wg-portal/secrets.env
      fi
      chown wg-portal:wg-portal /var/lib/wg-portal/wireguard.key /var/lib/wg-portal/secrets.env
      chmod 0600 /var/lib/wg-portal/wireguard.key /var/lib/wg-portal/secrets.env
    '';
  };
  systemd.services.vpn-interface = {
    description = "Create the WireGuard interface for Portal";
    after = [ "vpn-credentials.service" ];
    requires = [ "vpn-credentials.service" ];
    requiredBy = [ "wg-portal.service" ];
    before = [ "wg-portal.service" ];
    path = [
      pkgs.iproute2
      pkgs.wireguard-tools
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu
      if ! ip link show wg_in >/dev/null 2>&1; then ip link add wg_in type wireguard; fi
      wg set wg_in private-key /var/lib/wg-portal/wireguard.key listen-port 51820
      ip address replace ${tunnelAddress} dev wg_in
      ip link set dev wg_in mtu 1420 up
    '';
  };
  systemd.services.wg-portal = {
    description = "Private WireGuard management";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "vpn-interface.service"
    ];
    requires = [ "vpn-interface.service" ];
    unitConfig.RequiresMountsFor = [
      "/run/host-config"
      "/var/lib/wg-portal"
    ];
    path = [
      pkgs.bash
      pkgs.iproute2
      pkgs.wireguard-tools
    ];
    environment.WG_PORTAL_CONFIG = settings;
    serviceConfig = {
      User = "wg-portal";
      Group = "wg-portal";
      WorkingDirectory = "/var/lib/wg-portal";
      EnvironmentFile = [
        "/var/lib/wg-portal/secrets.env"
        "/run/host-config/portal.env"
      ];
      ExecStart = "${portal}/bin/wg-portal";
      Restart = "on-failure";
      RestartSec = 3;
      UMask = "0077";
      AmbientCapabilities = [ "CAP_NET_ADMIN" ];
      CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/lib/wg-portal" ];
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_NETLINK"
      ];
    };
  };
  # Nix controls the server address and client pool. Portal stores peers and other UI settings.
  systemd.services.vpn-defaults = {
    description = "Apply the declared WireGuard network";
    wantedBy = [ "multi-user.target" ];
    requires = [ "wg-portal.service" ];
    after = [ "wg-portal.service" ];
    path = [
      pkgs.curl
      pkgs.jq
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "wg-portal";
      Group = "wg-portal";
      EnvironmentFile = "/var/lib/wg-portal/secrets.env";
      RuntimeDirectory = "vpn-defaults";
      RuntimeDirectoryMode = "0700";
      UMask = "0077";
      Restart = "on-failure";
      RestartSec = 10;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/lib/wg-portal" ];
    };
    script = ''
      set -eu
      cd /run/vpn-defaults
      # Keep the API token out of process arguments and logs.
      printf 'user = "admin@localhost:%s"\n' "$WG_PORTAL_CORE_ADMIN_API_TOKEN" > curl.conf
      api=http://10.78.0.2:8888/api/v1/interface/by-id/wg_in
      curl --config curl.conf --fail --silent --show-error --retry 20 --retry-connrefused \
        --retry-delay 1 --max-time 5 --output interface.json "$api"
      jq -S . interface.json > current.json
      jq -S --arg address ${lib.escapeShellArg tunnelAddress} --arg subnet ${lib.escapeShellArg tunnelSubnet} \
        '.Addresses = [$address] | .PeerDefNetwork = [$subnet]' interface.json > network.json
      if [ ! -e /var/lib/wg-portal/defaults-v1 ]; then
        endpoint=$(curl -4 --fail --silent --show-error --max-time 10 https://api.ipify.org)
        # Check the response format before using it as an endpoint.
        jq -en --arg address "$endpoint" '$address | test("^([0-9]{1,3}\\.){3}[0-9]{1,3}$")' >/dev/null
        jq --arg endpoint "$endpoint:51820" \
          '.Mode = "server" | .PeerDefAllowedIPs = ["0.0.0.0/0"] |
           .PeerDefDns = ["1.1.1.1", "9.9.9.9"] | .PeerDefEndpoint = $endpoint |
           .PeerDefMtu = 1420 | .PeerDefPersistentKeepalive = 25' network.json > defaults.json
      else
        cp network.json defaults.json
      fi
      jq -S . defaults.json > desired.json
      if ! cmp -s current.json desired.json; then
        curl --config curl.conf --fail --silent --show-error --max-time 10 \
          --header 'Content-Type: application/json' --request PUT --data-binary @desired.json --output /dev/null "$api"
      fi
      touch /var/lib/wg-portal/defaults-v1
    '';
  };
  environment.systemPackages = [
    pkgs.wireguard-tools
    pkgs.curl
  ];
  services.journald.settings.Journal.SystemMaxUse = "64M";
  time.timeZone = "UTC";
}
