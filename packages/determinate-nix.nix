{
  determinate,
  pkgs,
  lib,
}:

# Keep the upstream Boost version while using packages from the shared input.
# Meson 1.12 generates incorrect unity paths for the nested libstore build directory.
determinate.inputs.nix.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideScope (
  _: prev: {
    boost =
      (pkgs.boost189.override {
        extraB2Args = [
          "--with-container"
          "--with-context"
          "--with-coroutine"
          "--with-iostreams"
          "--with-url"
          "--with-thread"
        ];
        enableIcu = false;
      }).overrideAttrs
        (old: {
          buildPhase = lib.replaceStrings [ "--without-python" ] [ "" ] old.buildPhase;
          installPhase = lib.replaceStrings [ "--without-python" ] [ "" ] old.installPhase;
        });
    nix-store = prev.nix-store.overrideAttrs (old: {
      mesonFlags = old.mesonFlags ++ [ "-Dunity=off" ];
    });
  }
)
