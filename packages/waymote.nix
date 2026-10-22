{
  lib,
  stdenvNoCC,
  fetchzip,
  autoPatchelfHook,
  makeWrapper,
  wayland,
  libxkbcommon,
  ffmpeg,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "waymote";
  version = "0.1.8";
  src = fetchzip {
    url = "https://github.com/rockorager/waymote/releases/download/v${finalAttrs.version}/waymote-server-${finalAttrs.version}-linux-x86_64.tar.gz";
    hash = "sha256-IUpa/8rcmSOPXOagcODkK5GCQQOEeo1AQgXGtNET2Wo=";
  };
  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [
    wayland
    libxkbcommon
  ];
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp bin/waymote-* $out/bin/
    wrapProgram $out/bin/waymote-streamd --prefix PATH : ${lib.makeBinPath [ ffmpeg ]}
    runHook postInstall
  '';
  meta = {
    description = "Wayland desktop streaming for Amp";
    homepage = "https://github.com/rockorager/waymote";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
})
