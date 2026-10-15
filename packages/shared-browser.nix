{
  lib,
  buildNpmPackage,
  fetchurl,
  nodejs_24,
  xorg-server,
  jq,
}:

buildNpmPackage {
  pname = "paseo-shared-browser";
  version = "2.0.1";
  src = fetchurl {
    url = "https://registry.npmjs.org/@omercnet/paseo-shared-browser/-/paseo-shared-browser-2.0.1.tgz";
    hash = "sha256-/XXmxMd8CHSZuJPuLJpfwFucknazw1lHJD7QA7SiZuI=";
  };
  nodejs = nodejs_24;
  npmDepsHash = "sha256-iwPn1bdlFEguZXcZy/8L5tlrAYE+DohOKhUeXSt+swM=";
  npmFlags = [ "--omit=dev" ];
  npmRebuildFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;
  nativeBuildInputs = [ jq ];
  postPatch = ''
    # The published lock file contains production dependencies only.
    ${jq}/bin/jq 'del(.devDependencies)' package.json > package.json.new
    mv package.json.new package.json
    substituteInPlace server/virtual-display.ts --replace-fail \
      '"/usr/bin/Xvfb"' '"${xorg-server}/bin/Xvfb"'
  '';
  buildPhase = ''
    runHook preBuild
    node --input-type=module <<'JS'
    import { build } from 'esbuild';
    await build({
      entryPoints: { supervisor: 'server/supervisor-entry.ts', 'shared-browser-mcp': 'server/mcp-entry.ts' },
      outdir: 'runtime', outExtension: { '.js': '.cjs' },
      bundle: true, platform: 'node', target: 'node24', format: 'cjs'
    });
    JS
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p $out/plugin $out/runtime
    cp -r client server shared index.client.tsx index.server.ts node_modules package.json $out/plugin/
    # Use the Nix source build instead of the npm executable copies.
    rm -rf $out/plugin/node_modules/agent-browser
    rm $out/plugin/node_modules/.bin/agent-browser
    jq 'del(.build)' paseo-plugin.json > $out/plugin/paseo-plugin.json
    cp runtime/*.cjs $out/runtime/
    echo '{"private":true,"type":"commonjs"}' > $out/runtime/package.json
    runHook postInstall
  '';
  meta = {
    description = "Persistent Chromium control for Paseo clients and agents";
    homepage = "https://github.com/omercnet/paseo-plugins/tree/main/paseo-shared-browser";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
