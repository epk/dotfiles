{
  lib,
  ghostty-bin,
  fetchurl,
}:

let
  release = (lib.importJSON ./cask-release.json).ghostty;
in
# nixpkgs can lag the official releases. The Homebrew cask API publishes the hash of each download.
ghostty-bin.overrideAttrs {
  inherit (release) version;
  src = fetchurl {
    url = "https://release.files.ghostty.org/${release.version}/Ghostty.dmg";
    inherit (release) sha256;
  };
}
