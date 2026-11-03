# Claude Code at the version in release.json. packages/overlay.nix replaces pkgs.claude-code with it.
{
  lib,
  stdenvNoCC,
  claude-code,
  fetchurl,
}:

let
  inherit (stdenvNoCC.hostPlatform) node;
  platform = "${node.platform}-${node.arch}";
  release = (lib.importJSON ./release.json).${platform};
in
# nixpkgs lags the official releases. Keep the nixpkgs wrapper and use the pinned npm binary.
claude-code.overrideAttrs (old: {
  inherit (release) version;
  src = fetchurl {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code-${platform}/-/claude-code-${platform}-${release.version}.tgz";
    inherit (release) hash;
  };
  # The npm archive contains the binary without zstd compression.
  installPhase =
    lib.replaceStrings
      [ "unzstd -q $src -o $out/bin/claude" ]
      [ "tar -xzOf $src package/claude > $out/bin/claude" ]
      old.installPhase;
})
