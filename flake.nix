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

    # nix-homebrew has no nixpkgs input to follow; brew-src is its only input.
    # The Homebrew version is pinned here; nix-homebrew follows it, so the
    # lock holds a single brew revision. A direct override of the transitive
    # input does not work: Nix drops `flake = false` on transitive overrides.
    brew-src = {
      url = "github:Homebrew/brew/7.0.1";
      flake = false;
    };
    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
      inputs.brew-src.follows = "brew-src";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    try = {
      url = "github:tobi/try";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
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
      # `host` is machine identity, `user` is account identity. Only the fields
      # that actually differ between machines are passed per host.
      mkDarwinConfiguration =
        {
          hostModule,
          host,
          email,
        }:
        nix-darwin.lib.darwinSystem {
          specialArgs = {
            inherit nix-index-database try host;
            user = {
              username = "aditya.sharma";
              name = "Aditya Sharma";
              inherit email;
            };
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
      darwinConfigurations = rec {
        adityas-shopitop = mkDarwinConfiguration {
          hostModule = ./hosts/adityas-shopitop;
          email = "aditya.sharma@shopify.com";
          host = {
            computerName = "adityas-shopitop";
            hostName = "adityas-shopitop";
            localHostName = "adityas-shopitop";
          };
        };

        adityas-macbook-pro = mkDarwinConfiguration {
          hostModule = ./hosts/adityas-macbook-pro;
          email = "git@adi.run";
          host = {
            computerName = "Aditya’s MacBook Pro";
            hostName = "Adityas-MacBook-Pro";
            localHostName = "Adityas-MacBook-Pro";
          };
        };

        # nh selects a Darwin configuration using the current macOS hostname
        # when no installable is supplied. Keep the lowercase name canonical
        # for scripts, while allowing `nh darwin switch` to resolve this host.
        "Adityas-MacBook-Pro" = adityas-macbook-pro;
      };

      # x86_64-linux is here so the CI eval job can run `nix fmt` with the same
      # pinned nixfmt the macOS hosts use.
      formatter = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ] (
        s: nixpkgs.legacyPackages.${s}.nixfmt
      );
    };
}
