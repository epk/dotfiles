# The packages that nixpkgs lags or omits. Renovate updates the pins next to each file.
{ inputs }:
final: prev:
let
  cua = final.callPackage ./cua { };
in
{
  _1password-cli = final.callPackage ./1password-cli { inherit (prev) _1password-cli; };
  _1password-gui = final.callPackage ./1password { inherit (prev) _1password-gui; };
  antigravity-cli = final.callPackage ./antigravity-cli { inherit (prev) antigravity-cli; };
  bb-app = final.callPackage ./bb-app { };
  chrome-devtools-mcp = final.callPackage ./chrome-devtools-mcp { };
  claude-code = final.callPackage ./claude-code { inherit (prev) claude-code; };
  codex = final.callPackage ./codex { };
  cua-cli = cua.cli;
  cua-driver = cua.driver;
  cua-spacesd = cua.spacesd;
  ghostty-bin = final.callPackage ./ghostty-bin { inherit (prev) ghostty-bin; };
  pomerado = final.callPackage ./pomerado { };
  slack = final.callPackage ./slack { inherit (prev) slack; };
  tailscale = final.callPackage ./tailscale { inherit (prev) tailscale; };
  tuple = final.callPackage ./tuple { inherit (prev) tuple; };
  vscode = final.callPackage ./vscode { inherit (prev) vscode; };
  wg-ez = final.callPackage ./wg-ez { src = inputs.wg-ez; };
}
