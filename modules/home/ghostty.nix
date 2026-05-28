{
  programs.ghostty = {
    enable = true;
    package = null;
    enableZshIntegration = true;
    settings = {
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
