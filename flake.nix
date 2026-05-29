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
      user = {
        username = "aditya.sharma";
        name = "Aditya Sharma";
        email = "aditya.sharma@shopify.com";
        computerName = "adityas-shopitop";
      };
    in
    {
      darwinConfigurations.adityas-shopitop = nix-darwin.lib.darwinSystem {
        inherit system;
        specialArgs = {
          inherit nix-index-database try user;
        };
        modules = [
          ./hosts/adityas-shopitop
          (
            { pkgs, ... }:
            {
              nixpkgs.overlays = [
                rust-overlay.overlays.default
                (_final: prev: {
                  python314 =
                    (prev.python314.override {
                      self = pkgs.python314;
                      sourceVersion = {
                        major = "3";
                        minor = "14";
                        patch = "5";
                        suffix = "";
                      };
                      hash = "sha256-fjJZe5nl2aOavtNd5Gk/oWnfPlhQ1MM0M3/9ahmjbbY=";
                    }).overrideAttrs
                      (old: {
                        patches = builtins.filter (
                          patch: builtins.baseNameOf patch != "hacl-static-ldeps-for-static-modules.patch"
                        ) old.patches;
                      });
                })
              ];
            }
          )
          home-manager.darwinModules.home-manager
          nix-homebrew.darwinModules.nix-homebrew
        ];
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt;
    };
}
