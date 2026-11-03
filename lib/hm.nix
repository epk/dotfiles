# Shared Home Manager settings for the NixOS and darwin hosts.
inputs: {
  useGlobalPkgs = true;
  useUserPackages = true;
  backupFileExtension = "before-nix";
  sharedModules = [
    inputs.nix-index-database.homeModules.default
    inputs.try.homeModules.default
  ];
}
