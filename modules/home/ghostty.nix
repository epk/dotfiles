{
  programs.ghostty = {
    enable = true;
    # The app itself comes from the Homebrew cask; only manage its config here.
    package = null;
    enableZshIntegration = true;
    settings = {
      # The cask is auto_updates, so Homebrew leaves upgrades to Sparkle. Point
      # Sparkle at tip to track main-branch builds instead of tagged releases.
      auto-update = "download";
      auto-update-channel = "tip";
      cursor-style = "block";
      cursor-style-blink = true;
      bold-is-bright = true;
      font-family = "JetBrainsMono Nerd Font";
      macos-titlebar-style = "tabs";
      macos-option-as-alt = true;
      working-directory = "home";
      window-inherit-working-directory = false;
      tab-inherit-working-directory = false;
    };
  };
}
