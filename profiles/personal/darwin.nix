{
  homebrew = {
    # `mas` is required by Homebrew Bundle to realize `masApps`. Codex and uv
    # intentionally use Homebrew because they move faster than the pinned
    # nixpkgs revision.
    brews = [
      "mas"
      "uv"
    ];

    casks = [
      "codex"
      "slack"
      "tailscale-app"
    ];

    masApps = {
      Infuse = 1136220934;
      Keynote = 361285480;
      Numbers = 361304891;
      Pages = 361309726;
      "Wipr 2" = 1662217862;
      WireGuard = 1451685025;
    };
  };
}
