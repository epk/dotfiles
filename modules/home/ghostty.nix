{
  programs.ghostty = {
    enable = true;
    package = null;
    settings = {
      cursor-style = "block";
      cursor-style-blink = true;
      bold-is-bright = true;
      macos-titlebar-style = "tabs";
      macos-option-as-alt = true;
      working-directory = "home";
      window-inherit-working-directory = false;
      tab-inherit-working-directory = false;
    };
  };
}
