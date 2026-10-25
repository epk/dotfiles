{
  lib,
  rustPlatform,
  src,
}:

rustPlatform.buildRustPackage {
  pname = "wg-ez";
  version = (lib.importTOML "${src}/Cargo.toml").package.version;
  inherit src;
  cargoLock.lockFile = "${src}/Cargo.lock";
  doCheck = false;
  postInstall = ''
    mkdir -p $out/share/wg-ez
    cp -r static locales $out/share/wg-ez/
  '';
  meta = {
    description = "WireGuard management with a private web interface";
    homepage = "https://github.com/wg-ez/wg-ez";
    license = lib.licenses.mit;
    mainProgram = "wg-ez";
    platforms = lib.platforms.linux;
  };
}
