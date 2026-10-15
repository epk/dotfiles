{
  lib,
  antigravity-cli,
  fetchurl,
  makeWrapper,
}:

let
  manifest = lib.importJSON ./antigravity-release.json;
in
# nixpkgs lags the official releases. Use the pinned manifest and turn off self-updates.
antigravity-cli.overrideAttrs (old: {
  inherit (manifest) version;
  src = fetchurl { inherit (manifest) url sha512; };
  nativeBuildInputs = old.nativeBuildInputs ++ [ makeWrapper ];
  postInstall = "wrapProgram $out/bin/agy --set AGY_CLI_DISABLE_AUTO_UPDATE 1";
})
