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
