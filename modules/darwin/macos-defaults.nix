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
    ActivityMonitor = {
      IconType = 5;
      OpenMainWindow = true;
      ShowCategory = 100;
      SortColumn = "CPUUsage";
      SortDirection = 0;
    };

    controlcenter = {
      BatteryShowPercentage = false;
      Bluetooth = true;
      FocusModes = true;
    };

    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.0;
      expose-group-apps = true;
      largesize = 83;
      magnification = true;
      minimize-to-application = true;
      showhidden = true;
      tilesize = 56;
      wvous-br-corner = 14;
    };

    finder = {
      AppleShowAllExtensions = true;
      FXDefaultSearchScope = "SCcf";
      FXEnableExtensionChangeWarning = false;
      FXPreferredViewStyle = "Nlsv";
      FXRemoveOldTrashItems = true;
      NewWindowTarget = "Home";
      ShowPathbar = true;
      ShowStatusBar = true;
      _FXSortFoldersFirst = true;
    };

    NSGlobalDomain = {
      AppleICUForce24HourTime = true;
      AppleInterfaceStyleSwitchesAutomatically = true;
      ApplePressAndHoldEnabled = false;
      AppleShowAllExtensions = true;
      AppleShowScrollBars = "Automatic";
      InitialKeyRepeat = 30;
      KeyRepeat = 2;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticInlinePredictionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSDocumentSaveNewDocumentsToCloud = false;
    };

    screencapture.type = "jpg";

    screensaver = {
      askForPassword = true;
      askForPasswordDelay = 0;
    };

    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;
    };

    WindowManager = {
      EnableTiledWindowMargins = false;
      EnableTilingByEdgeDrag = false;
      EnableTilingOptionAccelerator = false;
      EnableTopTilingByEdgeDrag = false;
      HideDesktop = true;
      StandardHideWidgets = false;
      StageManagerHideWidgets = false;
    };
  };
}
