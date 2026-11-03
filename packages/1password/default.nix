# 1Password for macOS at the version in release.json. packages/overlay.nix replaces pkgs._1password-gui with it.
{
  lib,
  _1password-gui,
  fetchurl,
}:

let
  release = lib.importJSON ./release.json;
in
# nixpkgs can lag the official releases. The Homebrew cask API publishes the hash of each download.
_1password-gui.overrideAttrs (old: {
  inherit (release) version;
  src = fetchurl {
    url = "https://downloads.1password.com/mac/1Password-${release.version}-aarch64.zip";
    inherit (release) sha256;
  };
  meta = old.meta // {
    platforms = [ "aarch64-darwin" ];
  };
})
