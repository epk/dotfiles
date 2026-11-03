# Ghostty for macOS at the version in release.json. packages/overlay.nix replaces pkgs.ghostty-bin with it.
{
  lib,
  ghostty-bin,
  fetchurl,
}:

let
  release = lib.importJSON ./release.json;
in
# nixpkgs can lag the official releases. The Homebrew cask API publishes the hash of each download.
ghostty-bin.overrideAttrs {
  inherit (release) version;
  src = fetchurl {
    url = "https://release.files.ghostty.org/${release.version}/Ghostty.dmg";
    inherit (release) sha256;
  };
}
