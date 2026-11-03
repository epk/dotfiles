# The keys that can decrypt each secret. The agenix CLI and checks/recipients.py read it.
let
  keys = import ./recipients.nix;
in
{
  "cachix/agent.age".publicKeys = [
    keys.server
    keys.recovery
  ];
  "tailscale/server.age".publicKeys = [
    keys.server
    keys.recovery
  ];
}
