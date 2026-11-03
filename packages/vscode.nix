{
  lib,
  vscode,
  fetchurl,
}:

let
  release = lib.importJSON ./vscode-release.json;
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
