{
  inputs,
  lib,
  pkgs,
  network,
  ...
}:
let
  inherit (import ../../../lib/network.nix) guestNameservers nonPublicV4;
  tunnelSubnet = "10.199.29.0/24";
  tunnelInterface = "wg_in";
  tunnelPort = 51820;
  # Nix owns the firewall and tunnel pool. The application owns keys, users and peers.
  settings = pkgs.writeText "wg-ez-settings.sql" ''
    PRAGMA foreign_keys = ON;
    BEGIN;
    UPDATE interfaces SET name = '${tunnelInterface}' WHERE name = 'wg0'
      AND NOT EXISTS (SELECT 1 FROM interfaces WHERE name = '${tunnelInterface}');
    UPDATE interfaces SET device = 'eth0', port = ${toString tunnelPort}, ipv4Cidr = '${tunnelSubnet}',
      mtu = 1420, firewallEnabled = 0 WHERE name = '${tunnelInterface}';
    UPDATE hooks SET preUp = ''', postUp = ''', preDown = ''', postDown = ''';
    COMMIT;
  '';
in
{
  nixpkgs.overlays = [ inputs.self.overlays.default ];
  networking = {
    hostName = "vpn";
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
    firewall = {
      checkReversePath = "loose";
      interfaces.eth0.allowedUDPPorts = [ tunnelPort ];
      extraInputRules = ''
        iifname "eth0" ip saddr ${network.hostAddress} tcp dport { 22, 8888 } accept
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
            elements = { ${lib.concatStringsSep ", " nonPublicV4} }
          }
          chain forward {
            type filter hook forward priority -10; policy drop;
            ct state invalid drop
            iifname "${tunnelInterface}" oifname "eth0" ip saddr ${tunnelSubnet} ip daddr != @non_public_v4 accept
            iifname "eth0" oifname "${tunnelInterface}" ip daddr ${tunnelSubnet} ct state { established, related } accept
          }
        '';
      };
      tables.vpn-nat = {
        family = "ip";
        content = ''
          chain postrouting {
            type nat hook postrouting priority srcnat; policy accept;
            iifname "${tunnelInterface}" oifname "eth0" ip saddr ${tunnelSubnet} masquerade
          }
        '';
      };
    };
  };

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  networking.useDHCP = false;
  networking.enableIPv6 = false;
  networking.nameservers = guestNameservers;
  # wg-quick resolves interface names through /etc/wireguard.
  environment.etc.wireguard.source = "/var/lib/wg-ez";
  nix.enable = false;
  documentation.enable = false;
  system.stateVersion = "26.11";
  services.journald.settings.Journal.RuntimeMaxUse = "16M";

  systemd.services.wg-ez-credentials = {
    description = "Create private WireGuard management credentials";
    before = [ "wg-ez.service" ];
    requiredBy = [ "wg-ez.service" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [
      pkgs.openssl
      pkgs.curl
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "wg-ez";
      StateDirectoryMode = "0700";
      UMask = "0077";
    };
    script = ''
      set -eu
      if [ ! -s /var/lib/wg-ez/credentials.env ]; then
        endpoint=$(curl -4 --fail --silent --show-error --retry 3 --max-time 15 https://api.ipify.org)
        printf '%s' "$endpoint" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
        {
          printf 'INIT_PASSWORD=%s\n' "$(openssl rand -hex 32)"
          printf 'INIT_HOST=%s\n' "$endpoint"
        } > /var/lib/wg-ez/credentials.env.new
        chmod 0600 /var/lib/wg-ez/credentials.env.new
        mv /var/lib/wg-ez/credentials.env.new /var/lib/wg-ez/credentials.env
      fi
    '';
  };
  systemd.services.wg-ez = {
    description = "Private WireGuard management";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "nftables.service"
      "wg-ez-credentials.service"
    ];
    requires = [
      "nftables.service"
      "wg-ez-credentials.service"
    ];
    path = [
      pkgs.bash
      pkgs.iproute2
      pkgs.wireguard-tools
      pkgs.coreutils
    ];
    environment = {
      HOST = "0.0.0.0";
      PORT = "8888";
      INSECURE = "true";
      IP_MODE = "ipv4";
      WG_INTERFACE = tunnelInterface;
      WG_CONF_DIR = "/var/lib/wg-ez";
      DB_PATH = "/var/lib/wg-ez/wg-ez.db";
      INIT_ENABLED = "true";
      INIT_USERNAME = "admin";
      INIT_PORT = toString tunnelPort;
      INIT_DNS = lib.concatStringsSep "," guestNameservers;
      INIT_IPV4_CIDR = tunnelSubnet;
      INIT_ALLOWED_IPS = "0.0.0.0/0";
    };
    # The first CLI call creates the database. Then apply the declared settings.
    preStart = ''
      ${pkgs.wg-ez}/bin/wg-ez cli clients:list >/dev/null
      ${pkgs.sqlite}/bin/sqlite3 -bail "$DB_PATH" < ${settings}
    '';
    serviceConfig = {
      EnvironmentFile = "/var/lib/wg-ez/credentials.env";
      ExecStart = "${pkgs.wg-ez}/bin/wg-ez serve";
      WorkingDirectory = "${pkgs.wg-ez}/share/wg-ez";
      StateDirectory = "wg-ez";
      StateDirectoryMode = "0700";
      Restart = "on-failure";
      RestartSec = 3;
      UMask = "0077";
      CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
      AmbientCapabilities = [ "CAP_NET_ADMIN" ];
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      InaccessiblePaths = [
        "-/nix/var/nix"
        "-/run/host"
      ];
      ReadWritePaths = [ "/var/lib/wg-ez" ];
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
}
