# The packages that nixpkgs lags or omits. Renovate updates the pins next to each file.
{ inputs }:
final: prev:
let
  cua = final.callPackage ./cua.nix { };
in
{
  antigravity-cli = final.callPackage ./antigravity-cli.nix { inherit (prev) antigravity-cli; };
  bb-app = final.callPackage ./bb-app { };
  chrome-devtools-mcp = final.callPackage ./chrome-devtools-mcp.nix { };
  claude-code = final.callPackage ./claude-code.nix { inherit (prev) claude-code; };
  codex = final.callPackage ./codex.nix { };
  cua-cli = cua.cli;
  cua-driver = cua.driver;
  cua-spacesd = cua.spacesd;
  ghostty-bin = final.callPackage ./ghostty-bin.nix { inherit (prev) ghostty-bin; };
  pomerado = final.callPackage ./pomerado { };
  slack = final.callPackage ./slack.nix { inherit (prev) slack; };
  tailscale = final.callPackage ./tailscale.nix { inherit (prev) tailscale; };
  tuple = final.callPackage ./tuple.nix { inherit (prev) tuple; };
  vscode = final.callPackage ./vscode.nix { inherit (prev) vscode; };
  wg-ez = final.callPackage ./wg-ez.nix { src = inputs.wg-ez; };
}
