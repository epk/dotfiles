let
  keys = import ./recipients.nix;
in
{
  "private/metadata.age".publicKeys = [
    keys.server
    keys.macos-personal
    keys.macos-work
    keys.recovery
  ];
  "tailscale/server.age".publicKeys = [
    keys.server
    keys.recovery
  ];
}
