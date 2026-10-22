# Shared Home Manager settings for the NixOS and darwin hosts.
{ nix-index-database, try }:
{
  useGlobalPkgs = true;
  useUserPackages = true;
  backupFileExtension = "before-nix";
  sharedModules = [
    nix-index-database.homeModules.default
    try.homeModules.default
  ];
}
