{
  lib,
  importNpmLock,
  nodejs_24,
  autoPatchelfHook,
  stdenv,
  libuv,
  makeWrapper,
}:
importNpmLock.buildNodeModules {
  npmRoot = ./.;
  nodejs = nodejs_24;
  derivationArgs = {
    pname = "bb-app";
    version = (lib.importJSON ./package.json).dependencies.bb-app;
    nativeBuildInputs = [
      autoPatchelfHook
      makeWrapper
    ];
    buildInputs = [
      stdenv.cc.cc.lib
      libuv
    ];
    npmRebuildFlags = [ "--ignore-scripts" ];
    buildPhase = ''
      runHook preBuild
      npm_config_build_from_source=true npm rebuild node-pty fs-native-extensions
      # SQLite uses its upstream Node-API addon. Keep only the glibc x86_64 build.
      find node_modules/better-sqlite3/prebuilds -mindepth 1 -maxdepth 1 \
        ! -name linux-x64.node -exec rm -rf {} +
      rm -rf node_modules/node-pty/prebuilds
      find node_modules/fs-native-extensions/prebuilds -mindepth 1 -maxdepth 1 \
        ! -name linux-x64 -exec rm -rf {} +
      runHook postBuild
    '';
    postInstall = ''
      mkdir -p $out/bin
      for command in bb bb-app bb-server bb-host-daemon; do
        makeWrapper ${nodejs_24}/bin/node $out/bin/$command \
          --add-flags "$out/node_modules/bb-app/dist/$command.js"
      done
    '';
    meta = {
      description = "Browser interface for local coding agents";
      homepage = "https://getbb.app";
      license = lib.licenses.mit;
      mainProgram = "bb-app";
      platforms = [ "x86_64-linux" ];
    };
  };
}
