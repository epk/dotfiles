{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  nodejs_26,
}:
stdenvNoCC.mkDerivation {
  pname = "chrome-devtools-mcp";
  version = "1.12.0";
  # The official npm archive includes its JavaScript dependencies.
  src = fetchurl {
    url = "https://registry.npmjs.org/chrome-devtools-mcp/-/chrome-devtools-mcp-1.12.0.tgz";
    hash = "sha512-lAGpH0zXT1ZdaPefP1KK/MvxwihOlu7VGQ7p4wbhD9OhN17vUC4KWk/ImUYR9DE4s+7r4r0ySV4xr2OkTa7ZMA==";
  };
  nativeBuildInputs = [ makeWrapper ];
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/libexec/chrome-devtools-mcp $out/bin
    cp -r build package.json LICENSE $out/libexec/chrome-devtools-mcp/
    makeWrapper ${nodejs_26}/bin/node $out/bin/chrome-devtools-mcp \
      --add-flags "$out/libexec/chrome-devtools-mcp/build/src/bin/chrome-devtools-mcp.js" \
      --set CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS 1
    runHook postInstall
  '';
  meta = {
    description = "Google Chrome DevTools server for MCP clients";
    homepage = "https://github.com/ChromeDevTools/chrome-devtools-mcp";
    license = lib.licenses.asl20;
    mainProgram = "chrome-devtools-mcp";
  };
}
