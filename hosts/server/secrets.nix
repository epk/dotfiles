{ pkgs, ... }:

{
  # Keep secret decryption separate from the SSH host key.
  age.identityPaths = [ "/var/lib/agenix/identity" ];
  age.verbosity = "summary";

  systemd.tmpfiles.rules = [
    "d /var/lib/agenix 0700 root root -"
    "z /var/lib/agenix/identity 0600 root root -"
  ];
  environment.systemPackages = [ pkgs.age ];
}
