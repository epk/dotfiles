# The 1Password CLI for macOS at the version in release.json. packages/overlay.nix replaces pkgs._1password-cli with it.
{
  lib,
  _1password-cli,
  fetchurl,
  unzip,
}:

let
  release = lib.importJSON ./release.json;
in
# Renovate updates this pin and the 1Password app pin in one pull request.
_1password-cli.overrideAttrs (old: {
  inherit (release) version;
  src = fetchurl {
    url = "https://cache.agilebits.com/dist/1P/op2/pkg/v${release.version}/op_darwin_arm64_v${release.version}.zip";
    inherit (release) sha256;
  };
  nativeBuildInputs = old.nativeBuildInputs ++ [ unzip ];
  unpackPhase = "unzip -q $src";
  meta = old.meta // {
    platforms = [ "aarch64-darwin" ];
  };
})
