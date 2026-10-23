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

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    determinate = {
      url = "github:DeterminateSystems/determinate";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nix.inputs.nixpkgs.follows = "nixpkgs";
    };

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
            inherit determinate nix-index-database try;
            user = import ./lib/user.nix // {
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

      # nix-update targets these attributes. Renovate cannot compute Nix hashes for wg-portal.
      packages = forAllSystems (
        pkgs:
        {
          agenix = agenix.packages.${pkgs.stdenv.hostPlatform.system}.default;
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          wg-portal = pkgs.callPackage ./packages/wg-portal.nix { };
        }
      );

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
