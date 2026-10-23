{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  nodejs_26,
}:
let
  release = builtins.fromJSON (builtins.readFile ./chrome-devtools-mcp-release.json);
in
stdenvNoCC.mkDerivation {
  pname = "chrome-devtools-mcp";
  inherit (release) version;
  # The official npm archive includes its JavaScript dependencies.
  src = fetchurl {
    url = "https://registry.npmjs.org/chrome-devtools-mcp/-/chrome-devtools-mcp-${release.version}.tgz";
    inherit (release) hash;
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
