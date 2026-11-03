# The Ghostty terminal and its settings. modules/home/darwin.nix imports it.
{ pkgs, ... }:

{
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty-bin;
    settings = {
      # The Nix store copy is read-only, so the built-in updater cannot replace it.
      auto-update = "off";
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
