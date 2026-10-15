let
  path = builtins.getEnv "DOTFILES_PRIVATE_CONFIG";
in
# Without the variable, use the neutral example values. No host may activate that build.
builtins.fromJSON (builtins.readFile (if path == "" then ./example-metadata.json else /. + path))
// {
  private = path != "";
}
