{
  lib,
  fetchurl,
  stdenv,
  autoPatchelfHook,
}:
let
  release = builtins.fromJSON (builtins.readFile ./wg-portal-release.json);
in
# Renovate updates the version and checksum together. GitHub publishes the checksum in the release asset digest.
stdenv.mkDerivation {
  pname = "wg-portal";
  inherit (release) version;
  src = fetchurl {
    name = "wg-portal_linux_amd64";
    url = "https://github.com/h44z/wg-portal/releases/download/v${release.version}/wg-portal_linux_amd64";
    sha256 = release.sha256;
  };
  # The source is a single binary, not an archive.
  dontUnpack = true;
  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];
  installPhase = ''
    runHook preInstall
    install -Dm555 $src $out/bin/wg-portal
    runHook postInstall
  '';
  meta = {
    description = "Web management for WireGuard interfaces and peers";
    homepage = "https://wgportal.org";
    license = lib.licenses.mit;
    mainProgram = "wg-portal";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
