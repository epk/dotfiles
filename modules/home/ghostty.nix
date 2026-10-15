{
  programs.ghostty = {
    enable = true;
    # Homebrew supplies Ghostty. Set only its configuration here.
    package = null;
    settings = {
      # Sparkle updates this cask. Homebrew does not upgrade it.
      # Select tip to use builds from the main branch.
      auto-update = "download";
      auto-update-channel = "tip";
      cursor-style = "block";
      cursor-style-blink = true;
      bold-color = "bright";
      font-family = "JetBrainsMono Nerd Font";
      macos-titlebar-style = "tabs";
      macos-option-as-alt = true;
      working-directory = "home";
      window-inherit-working-directory = false;
      tab-inherit-working-directory = false;
    };
  };
}
