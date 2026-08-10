{
  description = "Workstation configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    try = {
      url = "github:tobi/try";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nix-darwin,
      home-manager,
      nix-index-database,
      nix-homebrew,
      rust-overlay,
      try,
      ...
    }:
    let
      system = "aarch64-darwin";
      mkDarwinConfiguration =
        { hostModule, user }:
        nix-darwin.lib.darwinSystem {
          inherit system;
          specialArgs = {
            inherit nix-index-database try user;
          };
          modules = [
            hostModule
            { nixpkgs.overlays = [ rust-overlay.overlays.default ]; }
            home-manager.darwinModules.home-manager
            nix-homebrew.darwinModules.nix-homebrew
          ];
        };
    in
    {
      darwinConfigurations = {
        adityas-shopitop = mkDarwinConfiguration {
          hostModule = ./hosts/adityas-shopitop;
          user = {
            username = "aditya.sharma";
            name = "Aditya Sharma";
            email = "aditya.sharma@shopify.com";
            computerName = "adityas-shopitop";
            hostName = "adityas-shopitop";
            localHostName = "adityas-shopitop";
          };
        };

        adityas-macbook-pro = mkDarwinConfiguration {
          hostModule = ./hosts/adityas-macbook-pro;
          user = {
            username = "aditya.sharma";
            name = "Aditya Sharma";
            email = "git@adi.run";
            computerName = "Aditya’s MacBook Pro";
            hostName = "Adityas-MacBook-Pro";
            localHostName = "Adityas-MacBook-Pro";
          };
        };
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt;
    };
}
