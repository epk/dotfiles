# The Homebrew source that nix-homebrew installs. modules/darwin/packages.nix uses it.
{ lib }:
let
  release = lib.importJSON ./release.json;
  source = builtins.fetchGit {
    url = "https://github.com/Homebrew/brew";
    ref = "refs/tags/${release.version}";
    inherit (release) rev;
    shallow = true;
  };
in
# Renovate updates the release and commit together. Nix fetches that exact commit.
source
// {
  name = "brew-${release.version}";
  inherit (release) version;
}
