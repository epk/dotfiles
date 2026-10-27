{ self, pkgs }:
let
  inherit (pkgs) lib;
in
{
  format = self.formatter.${pkgs.stdenv.hostPlatform.system}.check "${self}";

  lint =
    pkgs.runCommand "lint"
      {
        nativeBuildInputs = with pkgs; [
          actionlint
          deadnix
          ruff
          shellcheck
        ];
      }
      ''
        cd ${self}
        # actionlint also runs shellcheck on each workflow script.
        # actionlint 1.7.12 does not know the ubuntu-26.04 label. GitHub supports it since September 2026.
        actionlint -ignore 'label "ubuntu-26\.04" is unknown' .github/workflows/*.yml
        shellcheck setup.sh
        ruff check --no-cache --select E,F,W,I,B .
        deadnix --fail .
        if grep -rIlE 'BEGIN [A-Z ]*PRIVATE KEY|AGE-SECRET-KEY-1[0-9A-Z]{50}|tskey-(auth|client)-[0-9A-Za-z]' .; then
          echo 'These files contain a private key or an enrollment key.' >&2
          exit 1
        fi
        touch $out
      '';

  policy = import ./policy.nix { inherit self pkgs; };

  ca-trust = import ./ca-trust.nix {
    inherit pkgs;
    bundles = map (c: c.config.environment.etc."ssl/certs/ca-certificates.crt".source) (
      if pkgs.stdenv.hostPlatform.isLinux then
        let
          server = self.nixosConfigurations.server;
        in
        [ server ] ++ map (vm: vm.config) (lib.attrValues server.config.microvm.vms)
      else
        lib.attrValues self.darwinConfigurations
    );
  };

  recipients = pkgs.runCommand "recipients" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    python3 ${./recipients.py} ${self}/secrets ${lib.escapeShellArg (builtins.toJSON (import ../secrets/agenix-rules.nix))}
    touch $out
  '';
}
// lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
  workshop-guest = import ./workshop-guest.nix { inherit self pkgs; };
  server = self.nixosConfigurations.server.config.system.build.toplevel;
}
// lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin (
  lib.mapAttrs (_: c: c.system) self.darwinConfigurations
)
