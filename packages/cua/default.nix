# The three Cua binaries at the versions in release.json. packages/overlay.nix adds them as pkgs.cua-*.
{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  stdenv,
  dbus,
  at-spi2-core,
  libX11,
  libXi,
  libXtst,
  libXfixes,
  libXrandr,
  libXcomposite,
  libXext,
  libxcb,
  libxkbcommon,
  libGL,
  wayland,
  libpulseaudio,
  pipewire,
  openssl,
  zlib,
}:
let
  releases = lib.importJSON ./release.json;
  urls = version: {
    driver = "https://github.com/trycua/cua/releases/download/cua-driver-rs-v${version}/cua-driver-rs-${version}-linux-x86_64-binary.tar.gz";
    spacesd = "https://github.com/trycua/cua/releases/download/cua-spacesd-v${version}/cua-spacesd-linux-x86_64.tar.gz";
    cli = "https://github.com/trycua/cua/releases/download/cua-sdk-v${version}/cua-cli-${version}-linux-x64.tar.gz";
  };
  libraries = [
    stdenv.cc.cc.lib
    dbus
    at-spi2-core
    libX11
    libXi
    libXtst
    libXfixes
    libXrandr
    libXcomposite
    libXext
    libxcb
    libxkbcommon
    libGL
    wayland
    libpulseaudio
    pipewire
    openssl
    zlib
  ];
  package =
    name: release:
    let
      executable = if name == "cli" then "cua" else "cua-${name}";
    in
    stdenvNoCC.mkDerivation {
      pname = "cua-${name}";
      inherit (release) version;
      src = fetchurl {
        url = (urls release.version).${name};
        inherit (release) sha256;
      };
      sourceRoot = ".";
      nativeBuildInputs = [
        autoPatchelfHook
        makeWrapper
      ];
      buildInputs = libraries;
      dontBuild = true;
      installPhase = ''
        runHook preInstall
        mkdir -p $out/libexec/cua $out/bin
        cp ${executable} $out/libexec/cua/
        ${lib.optionalString (
          name == "driver"
        ) "cp cua-cursor-theme libcua_driver_sdk.so cua_driver_node_runtime.node $out/libexec/cua/"}
        chmod +x $out/libexec/cua/${executable}
        makeWrapper $out/libexec/cua/${executable} $out/bin/${executable} \
          --prefix LD_LIBRARY_PATH : "$out/libexec/cua:${lib.makeLibraryPath libraries}"
        runHook postInstall
      '';
      meta = {
        description = "Cua desktop control ${name}";
        homepage = "https://github.com/trycua/cua";
        license = if name == "driver" then lib.licenses.mit else lib.licenses.fsl11Mit;
        mainProgram = executable;
        platforms = [ "x86_64-linux" ];
        sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      };
    };
in
lib.mapAttrs package releases
