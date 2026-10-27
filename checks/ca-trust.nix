{ pkgs, bundles }:
let
  inherit (pkgs) lib;
  # Names are certificate subject CNs. buildcatrust fails on blacklist names that the Mozilla store does not contain.
  distrusted = [
    "emSign Root CA - C1"
    "emSign ECC Root CA - C3"
    "emSign ECC Root CA - G3"
    "AAA Certificate Services"
  ];
in
pkgs.runCommand "ca-trust" { nativeBuildInputs = [ pkgs.openssl ]; } ''
  for bundle in ${lib.escapeShellArgs bundles}; do
    rm -rf certs && mkdir certs
    awk '/^-----BEGIN /{n++} n{print > ("certs/" n ".pem")}' "$bundle"
    for cert in certs/*.pem; do
      cn=$(openssl x509 -in "$cert" -noout -subject -nameopt multiline 2>/dev/null | sed -n 's/^ *commonName *= //p')
      case "$cn" in
        ${lib.concatMapStringsSep " | " lib.escapeShellArg distrusted}) ;;
        *) continue ;;
      esac
      # A plain PEM block has no trust rules, so OpenSSL trusts it for every purpose.
      if ! grep -q 'BEGIN TRUSTED' "$cert" ||
        openssl x509 -in "$cert" -noout -text 2>/dev/null | grep -A1 '^Trusted Uses:' | grep -q 'TLS Web Server'; then
        echo "$bundle trusts '$cn' for TLS servers." >&2
        exit 1
      fi
    done
  done
  touch $out
''
