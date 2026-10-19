# Guest networking

`modules/nixos/microvm-network.nix` declares separate routed IPv4 networks for guests.
Firecracker and Cloud Hypervisor use the same host network policy.
Microvm.nix creates each TAP device. Systemd-networkd supplies its address and routing policy.
Networkd matches only the declared TAP devices. It preserves routes and rules from Tailscale and DHCP.

## Access policy

Each guest can initiate connections to public IPv4 addresses through its declared uplink.
The host applies NAT at that uplink. Return traffic must belong to an established or related connection.
The rules reject other guest source addresses, invalid packets and unsolicited inbound connections.
Guest IPv6 traffic is blocked.

Guests cannot initiate connections to the host, private networks, link-local addresses, tailnet addresses or other guests.
The host can initiate guest administration connections. Guest replies to those connections are permitted.
The guest firewall must also permit the administration port.
These restrictions allow arbitrary public protocols and ports. They are not a domain or application allowlist.

The `microvm-filter` and `microvm-nat` nftables tables contain the guest policy.
The NixOS host firewall also uses nftables. Its declared SSH and Tailscale ports remain available.
Guest filtering runs before ordinary filter chains. Other tables cannot override its drop decisions.
Rule updates are atomic. They do not flush Tailscale tables or restart Tailscale.
Tailscale manages its own firewall rules. This module does not select or change its firewall backend.

A routing policy selects the main table for guest ingress before the Tailscale policy rules.
The nftables rules also require the declared output interface. A different route cannot bypass the guest policy.
The VM starts only after nftables and its TAP address are ready.

## Add a guest

Import the network module once. Declare each network under its VM name:

```nix
networking.microvm.guests.vpn = {
  interface = "vpn-tap";
  hostAddress = "10.77.0.5";
  guestAddress = "10.77.0.6";
  prefixLength = 30;
  uplink = "eno1";
};
```

Define the VM as `microvm.vms.vpn` with the same TAP interface.
Give the guest `10.77.0.6/30` and the gateway `10.77.0.5`.
Use a separate subnet for each VM. Prefix lengths must be between 24 and 30.
Workshop uses `10.77.0.0/30`.
No guest can use another guest TAP as its uplink.
This example does not create a VM or a WireGuard service.

A guest can initiate a WireGuard connection to a public peer through this network.
This policy does not publish an inbound WireGuard port or forward tunnel traffic between guests.
Define those requirements separately before adding a VPN gateway.
Keep tunnel routes inside the VPN guest unless a host route is explicitly required.

## Future inspection gateway

The TAP interface is the guest traffic boundary. An inspection gateway can replace its direct internet path later.
Enforce that path in the host firewall. Do not rely only on guest proxy environment variables.
If inspection is mandatory, block direct egress and stop traffic when the gateway is unavailable.
Apply the private destination restrictions to the gateway too.
Keep administration access separate from internet inspection.

Connection logs need no TLS interception. HTTPS content inspection requires a trusted CA certificate in the guest.
Keep the CA private key outside application guests. Protect and limit log retention because logs can contain credentials.
Certificate pinning, QUIC and other protocols require an explicit inspection or blocking policy.
This configuration deploys no proxy, inspection CA or packet-content logging.

## Activation

This change replaces the previous guest iptables service and changes the NixOS firewall backend.
It does not replace the host DHCP connection, SSH host keys or Tailscale state.
Use a persistent administrator connection during activation. Verify a fresh Tailscale SSH connection after activation.
Verify guest internet access and network isolation before treating deployment as complete.
Do not reboot the host as part of this network change.

Sources: [Firecracker host networking](https://github.com/firecracker-microvm/firecracker/blob/main/docs/prod-host-setup.md),
[NixOS nftables module](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/networking/nftables.nix),
[systemd network configuration](https://www.freedesktop.org/software/systemd/man/latest/systemd.network.html),
[mitmproxy modes](https://docs.mitmproxy.org/stable/concepts/modes/) and
[inspection certificates](https://docs.mitmproxy.org/stable/concepts/certificates/).
