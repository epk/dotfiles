final: prev:
let
  release = prev.lib.importJSON ./tailscale-release.json;
  src = builtins.fetchGit {
    url = "https://github.com/tailscale/tailscale";
    ref = "refs/tags/${release.tag}";
    inherit (release) rev;
    shallow = true;
  };
in
{
  tailscale = prev.tailscale.overrideAttrs {
    version = prev.lib.removePrefix "v" release.tag;
    inherit src;
    # Upstream records the vendor hash at each tag, so Renovate updates only the tag and commit.
    vendorHash = (prev.lib.importJSON "${src}/flakehashes.json").vendor.sri;
    # nixpkgs skips new sandbox-incompatible tests only after it packages a release.
    doCheck = false;
  };
}
