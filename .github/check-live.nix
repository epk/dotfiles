# Each host runs its deployed reload! or upgrade service against this revision.
let
  self = builtins.getFlake (toString ../.);
  deployed = builtins.getFlake "github:epk/dotfiles";
  inherit (self.inputs.nixpkgs) lib;
  upgrade = deployed.nixosConfigurations.server.config.system.autoUpgrade;
  # Add a deployed output name here to rename or remove it. Then run setup.sh or switch on that host.
  retired = [ ];
  exists = outputs: name: outputs ? ${name} || lib.elem name retired;
in
assert lib.all (exists self.darwinConfigurations) (lib.attrNames deployed.darwinConfigurations);
assert exists self.nixosConfigurations (lib.last (lib.splitString "#" upgrade.flake));
"The deployed hosts find their outputs.\n"
