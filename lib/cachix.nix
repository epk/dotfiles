{
  # CI pushes to this cache. The server and the Macs download from it.
  epk = {
    url = "https://epk.cachix.org";
    publicKey = "epk.cachix.org-1:qmEB4bwoUpFURWwQ3RsCyWU6SHKIq135q/YZx7alcV8=";
  };

  # Cachix omits uploads that this upstream cache already supplies.
  community = {
    url = "https://nix-community.cachix.org";
    publicKey = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
  };

  # devenv publishes its packages and rolling nixpkgs builds in this cache.
  devenv = {
    url = "https://devenv.cachix.org";
    publicKey = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
  };
}
