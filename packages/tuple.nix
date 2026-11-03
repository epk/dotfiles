{
  lib,
  tuple,
  fetchurl,
  runCommand,
  unzip,
}:

let
  release = (lib.importJSON ./cask-release.json).tuple;
  # The cask version also has the build date and commit: 3.3.19,2026-11-02,65446df1e4.
  version = lib.head (lib.splitString "," release.version);
  archive = fetchurl {
    url = "https://d32ifkf9k9ezcg.cloudfront.net/production/sparkle/tuple-${
      lib.replaceStrings [ "," ] [ "-" ] release.version
    }.zip";
    inherit (release) sha256;
  };
in
# nixpkgs lags the official releases. The Homebrew cask API publishes the hash of the archive.
# The nixpkgs install step copies the unpacked application bundle from src.
tuple.overrideAttrs (old: {
  inherit version;
  src = runCommand "Tuple.app" { nativeBuildInputs = [ unzip ]; } ''
    unzip -q ${archive}
    mv Tuple.app $out
  '';
  meta = old.meta // {
    platforms = [ "aarch64-darwin" ];
  };
})
