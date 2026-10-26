{
  lib,
  importNpmLock,
  nodejs_24,
  makeWrapper,
  autoPatchelfHook,
  stdenv,
  playwright-driver,
  playwright-test,
}:
importNpmLock.buildNodeModules {
  npmRoot = ./.;
  nodejs = nodejs_24;
  derivationArgs = {
    pname = "pomerado";
    version = (lib.importJSON ./package.json).dependencies.pomerado;
    nativeBuildInputs = [
      makeWrapper
      autoPatchelfHook
    ];
    buildInputs = [ stdenv.cc.cc.lib ];
    npmRebuildFlags = [ "--ignore-scripts" ];
    postInstall = ''
      # Keep the Playwright library and browser revisions together during flake updates.
      rm -rf $out/node_modules/playwright $out/node_modules/playwright-core
      ln -s ${playwright-test}/lib/node_modules/playwright $out/node_modules/playwright
      ln -s ${playwright-test}/lib/node_modules/playwright-core $out/node_modules/playwright-core
      mkdir -p $out/bin
      for command in pomerado pomerado-mcp; do
        entry=cli
        if [ "$command" = pomerado-mcp ]; then entry=mcp-cli; fi
        makeWrapper ${nodejs_24}/bin/node $out/bin/$command \
          --add-flags "$out/node_modules/pomerado/dist/typescript/src/standalone/$entry.js" \
          --set PLAYWRIGHT_BROWSERS_PATH ${
            playwright-driver.selectBrowsers {
              withFirefox = false;
              withWebkit = false;
            }
          } \
          --set PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD 1
      done
      wrapProgram $out/bin/pomerado-mcp --run '
        if [ -r "$HOME/.config/workshop/pomerado.env" ]; then
          set -a
          . "$HOME/.config/workshop/pomerado.env"
          set +a
        fi
      '
    '';
    meta = {
      description = "Create website integrations for MCP clients";
      homepage = "https://github.com/Pomerado/pomerado";
      license = lib.licenses.mit;
      mainProgram = "pomerado";
      platforms = [ "x86_64-linux" ];
    };
  };
}
