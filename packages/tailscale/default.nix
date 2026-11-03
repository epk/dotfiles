# Tailscale at the tag in release.json. packages/overlay.nix replaces pkgs.tailscale with it.
{ lib, tailscale }:
let
  release = lib.importJSON ./release.json;
  src = builtins.fetchGit {
    url = "https://github.com/tailscale/tailscale";
    ref = "refs/tags/${release.tag}";
    inherit (release) rev;
    shallow = true;
  };
in
tailscale.overrideAttrs {
  version = lib.removePrefix "v" release.tag;
  inherit src;
  # Upstream records the vendor hash at each tag, so Renovate updates only the tag and commit.
  vendorHash = (lib.importJSON "${src}/flakehashes.json").vendor.sri;
  # nixpkgs skips new sandbox-incompatible tests only after it packages a release.
  doCheck = false;
}
