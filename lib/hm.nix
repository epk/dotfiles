# Shared Home Manager settings. modules/darwin/default.nix and modules/nixos/home.nix use them.
inputs: {
  useGlobalPkgs = true;
  useUserPackages = true;
  backupFileExtension = "before-nix";
  sharedModules = [
    inputs.nix-index-database.homeModules.default
    inputs.try.homeModules.default
  ];
}
