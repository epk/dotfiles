{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  inherit (stdenvNoCC.hostPlatform) node;
  platform = "${node.platform}-${node.arch}";
  release = (lib.importJSON ./codex-release.json).${platform};
  target =
    {
      darwin-arm64 = "aarch64-apple-darwin";
      linux-x64 = "x86_64-unknown-linux-musl";
    }
    .${platform};
in
# nixpkgs lags the official releases and builds Codex from source.
# The npm archive has the bwrap and rg layout that the managed daemon validates.
stdenvNoCC.mkDerivation {
  pname = "codex";
  inherit (release) version;
  src = fetchurl {
    url = "https://registry.npmjs.org/@openai/codex/-/codex-${release.version}-${platform}.tgz";
    inherit (release) hash;
  };
  dontBuild = true;
  # A strip removes the Apple code signature. The Linux binaries are static musl builds.
  dontFixup = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp -r vendor/${target} $out/libexec
    ln -s $out/libexec/bin/codex $out/bin/codex
    runHook postInstall
  '';
  meta = {
    description = "OpenAI coding agent for the terminal";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
