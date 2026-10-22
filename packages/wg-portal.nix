{
  lib,
  fetchFromGitHub,
  buildGoModule,
  buildNpmPackage,
}:
let
  version = "2.3.1";
  src = fetchFromGitHub {
    owner = "h44z";
    repo = "wg-portal";
    tag = "v${version}";
    hash = "sha256-nkDCEtG4gYv/8pppJtlGQcHhuupL9nnw90XKxRym5gA=";
  };
  frontend = buildNpmPackage {
    pname = "wg-portal-frontend";
    inherit version src;
    sourceRoot = "source/frontend";
    npmDepsHash = "sha256-NTipEmFjHZ96HwX8jznMG/eIZfHw4KAd/2b39xkBlxU=";
    makeCacheWritable = true;
    env.DIST_OUT_DIR = "dist";
    installPhase = ''
      runHook preInstall
      cp -r dist $out
      runHook postInstall
    '';
  };
in
buildGoModule {
  pname = "wg-portal";
  inherit version src;
  vendorHash = "sha256-Dkn+tSKktPfcOxNY7Ogp5ame8c9WH1goIFTFKJpm4sk=";
  subPackages = [ "cmd/wg-portal" ];
  env.CGO_ENABLED = 0;
  tags = [ "netgo" ];
  ldflags = [
    "-s"
    "-w"
    "-X github.com/h44z/wg-portal/internal/server.Version=v${version}"
  ];
  preBuild = ''
    cp -r ${frontend} internal/app/api/core/frontend-dist
  '';
  doCheck = false;
  passthru = { inherit frontend; };
  meta = {
    description = "Web management for WireGuard interfaces and peers";
    homepage = "https://wgportal.org";
    license = lib.licenses.mit;
    mainProgram = "wg-portal";
    platforms = lib.platforms.linux;
  };
}
