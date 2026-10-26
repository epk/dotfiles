{ lib }:
lib.genAttrs
  [
    "browser"
    "claudeCode"
    "codex"
    "gemini"
    "antigravity"
    "paseo"
    "bb"
    "cua"
    "amp"
    "pomerado"
    "omp"
  ]
  (name: {
    enable = lib.mkEnableOption "Workshop ${name}";
  })
