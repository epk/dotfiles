{
  description = "Workstation and server configurations";

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

    # nix-homebrew uses brew-src as its only input.
    # Pin Homebrew here. Let nix-homebrew use the same input.
    # Nix removes `flake = false` from overrides of indirect inputs.
    brew-src = {
      url = "github:Homebrew/brew/7.0.8";
      flake = false;
    };
    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
      inputs.brew-src.follows = "brew-src";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    determinate.url = "github:DeterminateSystems/determinate";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    try = {
      url = "github:tobi/try";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      agenix,
      determinate,
      disko,
      microvm,
      nix-index-database,
      nix-homebrew,
      rust-overlay,
      try,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      forAllSystems =
        f: lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ] (system: f nixpkgs.legacyPackages.${system});

      mkDarwinConfiguration =
        role:
        nix-darwin.lib.darwinSystem {
          specialArgs = {
            inherit nix-index-database try;
            user = {
              username = "aditya.sharma";
              name = "Aditya Sharma";
              signingPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE/Cr+bIMxMzkk8dN7xxRsaJeHRifwlyTuh/ja9Uy9MN";
              inherit role;
            };
          };
          modules = [
            ./hosts/macos-${role}
            { nixpkgs.overlays = [ rust-overlay.overlays.default ]; }
            home-manager.darwinModules.home-manager
            nix-homebrew.darwinModules.nix-homebrew
          ];
        };
    in
    {
      # reload! selects macos-<role>. Build each name from its role so that the two cannot differ.
      darwinConfigurations = lib.genAttrs' [ "personal" "work" ] (
        role: lib.nameValuePair "macos-${role}" (mkDarwinConfiguration role)
      );

      nixosConfigurations.server = lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit nixpkgs inputs;
        };
        modules = [
          ./hosts/server
          agenix.nixosModules.default
          determinate.nixosModules.default
          microvm.nixosModules.host
          disko.nixosModules.disko
        ];
      };

      packages = forAllSystems (pkgs: {
        inherit (pkgs) age;
        agenix = agenix.packages.${pkgs.stdenv.hostPlatform.system}.default;
      });

      formatter = forAllSystems (
        pkgs:
        pkgs.treefmt.withConfig {
          runtimeInputs = with pkgs; [
            nixfmt
            ruff
            shfmt
          ];
          settings = {
            tree-root-file = "flake.nix";
            on-unmatched = "info";
            formatter = {
              nixfmt = {
                command = "nixfmt";
                includes = [ "*.nix" ];
              };
              ruff = {
                command = "ruff";
                options = [
                  "format"
                  "--no-cache"
                ];
                includes = [ "*.py" ];
              };
              shfmt = {
                command = "shfmt";
                options = [
                  "-w"
                  "-i"
                  "2"
                ];
                includes = [ "*.sh" ];
              };
            };
          };
        }
      );

      checks = forAllSystems (pkgs: import ./checks { inherit self pkgs; });
    };
}
