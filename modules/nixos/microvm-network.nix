{
  config,
  lib,
  ...
}:
let
  cfg = config.networking.microvm;
  guests = lib.attrValues cfg.guests;
  interfaces = map (guest: guest.interface) guests;
  addresses = map (guest: guest.guestAddress) guests;
  quote = builtins.toJSON;
  each = f: lib.concatMapStringsSep "\n" f guests;
  interfaceType = lib.types.strMatching "[a-zA-Z0-9][a-zA-Z0-9_-]{0,14}";
  addressType =
    lib.types.addCheck (lib.types.strMatching "(0|[1-9][0-9]{0,2})(\\.(0|[1-9][0-9]{0,2})){3}")
      (address: lib.all (octet: lib.toInt octet <= 255) (lib.splitString "." address));
  number =
    address: lib.foldl' (value: octet: value * 256 + lib.toInt octet) 0 (lib.splitString "." address);
  blockSize = guest: lib.foldl' (value: _: value * 2) 1 (lib.range guest.prefixLength 31);
  first = guest: builtins.div (number guest.hostAddress) (blockSize guest) * blockSize guest;
  last = guest: first guest + blockSize guest - 1;
  private =
    address:
    let
      octets = map lib.toInt (lib.splitString "." address);
    in
    builtins.head octets == 10
    || (builtins.head octets == 172 && builtins.elemAt octets 1 >= 16 && builtins.elemAt octets 1 <= 31)
    || (builtins.head octets == 192 && builtins.elemAt octets 1 == 168);
in
{
  options.networking.microvm.guests = lib.mkOption {
    default = { };
    description = "Separate IPv4 networks for guests with public internet access.";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          interface = lib.mkOption {
            type = interfaceType;
            description = "TAP interface created by microvm.nix.";
          };
          hostAddress = lib.mkOption {
            type = addressType;
            description = "Host IPv4 address on the guest network.";
          };
          guestAddress = lib.mkOption {
            type = addressType;
            description = "Only source IPv4 address permitted from this guest.";
          };
          prefixLength = lib.mkOption {
            type = lib.types.ints.between 24 30;
            default = 30;
            description = "Prefix length of the private guest network.";
          };
          uplink = lib.mkOption {
            type = interfaceType;
            description = "Only host interface permitted for guest internet traffic.";
          };
        };
      }
    );
  };

  config = lib.mkIf (guests != [ ]) {
    assertions = [
      {
        assertion = lib.length (lib.unique interfaces) == lib.length interfaces;
        message = "Give each guest a separate TAP interface.";
      }
      {
        assertion = lib.length (lib.unique addresses) == lib.length addresses;
        message = "Give each guest a separate IPv4 address.";
      }
      {
        assertion = lib.all (
          guest:
          private guest.hostAddress
          && guest.hostAddress != guest.guestAddress
          && number guest.hostAddress > first guest
          && number guest.hostAddress < last guest
          && number guest.guestAddress > first guest
          && number guest.guestAddress < last guest
        ) guests;
        message = "Use separate host and guest addresses in the same private subnet. Do not use network or broadcast addresses.";
      }
      {
        assertion = lib.all (a: lib.all (b: a == b || last a < first b || last b < first a) guests) guests;
        message = "Do not overlap guest subnets.";
      }
      {
        assertion = lib.all (guest: !(builtins.elem guest.uplink interfaces)) guests;
        message = "Do not use another guest TAP interface as an internet uplink.";
      }
    ];

    boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = true;
    # networkd owns only the declared TAP devices. Preserve routes and rules from Tailscale and DHCP.
    systemd.network = {
      enable = true;
      # Guest TAP devices must not delay the host network-online target. Each guest has its own readiness unit.
      wait-online.enable = lib.mkDefault config.networking.useNetworkd;
      config.networkConfig = {
        IPv4Forwarding = true;
        ManageForeignRoutes = false;
        ManageForeignRoutingPolicyRules = false;
        ManageForeignNextHops = false;
      };
      networks = lib.mapAttrs' (
        name: guest:
        lib.nameValuePair "30-microvm-${name}" {
          matchConfig.Name = guest.interface;
          linkConfig.RequiredForOnline = false;
          address = [ "${guest.hostAddress}/${toString guest.prefixLength}" ];
          networkConfig = {
            DHCP = "no";
            LinkLocalAddressing = "no";
            IPv6AcceptRA = false;
            ConfigureWithoutCarrier = true;
          };
          # Select the main table before Tailscale policy rules. The firewall also checks the output interface.
          routingPolicyRules = [
            {
              IncomingInterface = guest.interface;
              Family = "ipv4";
              Priority = 5200;
              Table = "main";
            }
          ];
        }
      ) cfg.guests;
    };

    networking.nftables = {
      enable = true;
      # Reload only our declared tables. Never remove Tailscale tables.
      flushRuleset = false;
      tables.microvm-filter = {
        family = "inet";
        content = ''
          set guest_interfaces {
            type ifname
            elements = { ${lib.concatMapStringsSep ", " quote interfaces} }
          }
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
          chain input {
            type filter hook input priority -10; policy accept;
            iifname @guest_interfaces jump guest_input
          }
          chain guest_input {
            ct state invalid counter drop
            ${each (
              guest:
              "iifname ${quote guest.interface} ip saddr ${guest.guestAddress} ct state { established, related } accept"
            )}
            counter drop
          }
          chain forward {
            type filter hook forward priority -10; policy accept;
            iifname @guest_interfaces jump guest_egress
            oifname @guest_interfaces jump guest_return
          }
          chain guest_egress {
            ct state invalid counter drop
            meta nfproto != ipv4 counter drop
            fib daddr type local counter drop
            ip daddr @non_public_v4 counter drop
            ${each (
              guest:
              "iifname ${quote guest.interface} ip saddr ${guest.guestAddress} oifname ${quote guest.uplink} accept"
            )}
            counter drop
          }
          chain guest_return {
            ct state invalid counter drop
            ${each (
              guest:
              "iifname ${quote guest.uplink} oifname ${quote guest.interface} ip daddr ${guest.guestAddress} ct state { established, related } accept"
            )}
            counter drop
          }
        '';
      };
      tables.microvm-nat = {
        family = "ip";
        content = ''
          chain postrouting {
            type nat hook postrouting priority srcnat; policy accept;
            ${each (
              guest:
              "iifname ${quote guest.interface} ip saddr ${guest.guestAddress} oifname ${quote guest.uplink} masquerade"
            )}
          }
        '';
      };
    };

    # Start the guest only after its firewall and address are ready, including without a TAP carrier.
    # A stop of nftables removes the guest rules, so it also stops the guest.
    # A networkd restart must not restart the guest. Without networkd, wait-online fails and the guest does not start.
    systemd.services = lib.mapAttrs' (
      name: guest:
      lib.nameValuePair "microvm-network-${name}" {
        requires = [
          "microvm-tap-interfaces@${name}.service"
          "nftables.service"
        ];
        wants = [ "systemd-networkd.service" ];
        after = [
          "microvm-tap-interfaces@${name}.service"
          "nftables.service"
          "systemd-networkd.service"
        ];
        before = [ "microvm@${name}.service" ];
        requiredBy = [ "microvm@${name}.service" ];
        partOf = [ "microvm@${name}.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${config.systemd.package}/lib/systemd/systemd-networkd-wait-online --interface=${guest.interface}:no-carrier --ipv4 --timeout=30";
        };
      }
    ) cfg.guests;
  };
}
