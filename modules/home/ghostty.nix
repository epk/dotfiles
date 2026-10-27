{
  programs.ghostty = {
    enable = true;
    # Homebrew supplies Ghostty. Set only its configuration here.
    package = null;
    settings = {
      # Sparkle updates this cask. Homebrew does not upgrade it.
      auto-update = "download";
      auto-update-channel = "stable";
      cursor-style = "block";
      cursor-style-blink = true;
      bold-color = "bright";
      copy-on-select = "clipboard";
      link-osc8 = false;
      window-padding-balance = "equal";
      font-family = "JetBrainsMono Nerd Font";
      macos-titlebar-style = "tabs";
      macos-option-as-alt = true;
      working-directory = "home";
      window-inherit-working-directory = false;
      tab-inherit-working-directory = false;
    };
  };
}
