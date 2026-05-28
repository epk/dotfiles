{
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  power.sleep = {
    computer = "never";
    display = "never";
  };

  system.defaults = {
    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.0;
      expose-group-apps = true;
      minimize-to-application = true;
      showhidden = true;
      tilesize = 76;
      wvous-br-corner = 14;
    };

    finder = {
      FXDefaultSearchScope = "SCcf";
      FXPreferredViewStyle = "Nlsv";
      FXRemoveOldTrashItems = true;
    };

    NSGlobalDomain = {
      InitialKeyRepeat = 30;
      KeyRepeat = 2;
    };

    screencapture.type = "jpg";

    WindowManager = {
      EnableTiledWindowMargins = false;
      EnableTilingByEdgeDrag = false;
      EnableTilingOptionAccelerator = false;
      EnableTopTilingByEdgeDrag = false;
      HideDesktop = true;
      StandardHideWidgets = true;
      StageManagerHideWidgets = true;
    };
  };
}
