{
  lib,
  slack,
  fetchurl,
}:

let
  release = (lib.importJSON ./cask-release.json).slack;
in
# nixpkgs lags the official releases. The Homebrew cask API publishes the hash of each download.
slack.overrideAttrs (old: {
  inherit (release) version;
  src = fetchurl {
    url = "https://downloads.slack-edge.com/desktop-releases/mac/arm64/${release.version}/Slack-${release.version}-macOS.dmg";
    inherit (release) sha256;
  };
  meta = old.meta // {
    platforms = [ "aarch64-darwin" ];
  };
})
