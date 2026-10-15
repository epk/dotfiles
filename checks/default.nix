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
        actionlint .github/workflows/*.yml
        shellcheck setup.sh .github/*.sh automation/*.sh
        ruff check --no-cache --select E,F,W,I,B .
        deadnix --fail .
        if grep -rIlE 'BEGIN [A-Z ]*PRIVATE KEY|AGE-SECRET-KEY-1[0-9A-Z]{50}|tskey-(auth|client)-[0-9A-Za-z]' .; then
          echo 'These files contain a private key or an enrollment key.' >&2
          exit 1
        fi
        touch $out
      '';

  policy = import ./policy.nix { inherit self pkgs; };

  recipients = pkgs.runCommand "recipients" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    python3 ${./recipients.py} ${self}/secrets ${lib.escapeShellArg (builtins.toJSON (import ../secrets/agenix-rules.nix))}
    touch $out
  '';
}
// lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
  workshop-guest = import ./workshop-guest.nix { inherit self pkgs; };
}
