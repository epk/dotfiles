{
  # CI pushes to this cache. The server and the Macs download from it.
  epk = {
    url = "https://epk.cachix.org";
    publicKey = "epk.cachix.org-1:qmEB4bwoUpFURWwQ3RsCyWU6SHKIq135q/YZx7alcV8=";
  };

  # devenv publishes its packages and rolling nixpkgs builds in this cache.
  devenv = {
    url = "https://devenv.cachix.org";
    publicKey = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
  };
}
