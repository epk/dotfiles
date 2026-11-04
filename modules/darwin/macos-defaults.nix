# macOS preferences, such as Touch ID for sudo and system.defaults. modules/darwin/default.nix imports it.
{
  config,
  lib,
  user,
  ...
}:

let
  home = config.users.users.${user.username}.home;
  spotlightExclusions = map (p: "${home}/${p}") [
    "world"
    "src"
    "pkg"
    "bin"
    ".shop-bb-fy"
    ".lima"
    ".local"
    ".cargo"
    ".bun"
    ".omp"
    ".vscode"
    ".codex"
    ".claude"
    ".npm"
    ".dev"
    ".config"
    ".cache"
    ".nvm"
    ".paseo"
    ".tenv"
    ".kube"
    ".bundle"
    "Library/Caches"
  ];
in
{
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  # Do not use power.sleep. Its systemsetup command changes only the AC profile.
  # Use pmset -a to set the AC and battery profiles.
  # mds reads the Spotlight exclusions only at boot. SIP blocks a restart of mds.
  system.activationScripts.postActivation.text = ''
    pmset -a sleep 0 displaysleep 0

    spotlight_plist=/System/Volumes/Data/.Spotlight-V100/VolumeConfiguration.plist
    if [ -f "$spotlight_plist" ]; then
      /usr/libexec/PlistBuddy -c "Print :Exclusions" "$spotlight_plist" >/dev/null 2>&1 \
        || /usr/libexec/PlistBuddy -c "Add :Exclusions array" "$spotlight_plist"
      for p in ${lib.escapeShellArgs spotlightExclusions}; do
        /usr/libexec/PlistBuddy -c "Print :Exclusions" "$spotlight_plist" | grep -qxF "    $p" \
          || /usr/libexec/PlistBuddy -c "Add :Exclusions: string $p" "$spotlight_plist"
      done
    fi
  '';

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
