# VS Code for macOS at the version in release.json. packages/overlay.nix replaces pkgs.vscode with it.
{
  lib,
  vscode,
  fetchurl,
}:

let
  release = lib.importJSON ./release.json;
in
# nixpkgs lags the official releases.
vscode.overrideAttrs (old: {
  inherit (release) version;
  src = fetchurl {
    name = "VSCode_${release.version}_darwin-arm64.zip";
    url = "https://update.code.visualstudio.com/${release.version}/darwin-arm64/stable";
    inherit (release) sha256;
  };
  meta = old.meta // {
    platforms = [ "aarch64-darwin" ];
  };
})
