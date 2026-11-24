# Tailscale at the tag in release.json. packages/overlay.nix replaces pkgs.tailscale with it.
{
  lib,
  tailscale,
  buildGo127Module,
  go_1_27,
  fetchurl,
}:
let
  release = lib.importJSON ./release.json;
  src = builtins.fetchGit {
    url = "https://github.com/tailscale/tailscale";
    ref = "refs/tags/${release.tag}";
    inherit (release) rev;
    shallow = true;
  };
  # A tag can require a Go patch release that nixpkgs does not package yet.
  go =
    if lib.versionAtLeast go_1_27.version "1.27.4" then
      go_1_27
    else
      go_1_27.overrideAttrs {
        version = "1.27.4";
        src = fetchurl {
          url = "https://go.dev/dl/go1.27.4.src.tar.gz";
          hash = "sha256-c8+4VxrsDAEXdofbhxY9Rqog6XeWcncokaoXZU2aYJk=";
        };
      };
in
(tailscale.override { buildGo127Module = buildGo127Module.override { inherit go; }; }).overrideAttrs
  {
    version = lib.removePrefix "v" release.tag;
    inherit src;
    # Upstream records the vendor hash at each tag, so Renovate updates only the tag and commit.
    vendorHash = (lib.importJSON "${src}/flakehashes.json").vendor.sri;
    # The nixpkgs patches are upstream commits that newer tags already contain.
    patches = [ ];
    # nixpkgs skips new sandbox-incompatible tests only after it packages a release.
    doCheck = false;
  }
