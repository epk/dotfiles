{
  config,
  pkgs,
  user,
  ...
}:

{
  programs.diff-so-fancy = {
    enable = true;
    enableGitIntegration = true;
  };

  programs.git = {
    enable = true;
    ignores = [
      ".DS_Store"
      "*.swp"
      "*.swo"
    ];
    includes = [
      {
        path = "${config.home.homeDirectory}/.config/dev/gitconfig";
      }
    ];
    signing = {
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE/Cr+bIMxMzkk8dN7xxRsaJeHRifwlyTuh/ja9Uy9MN";
      format = "ssh";
      signer = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
      signByDefault = true;
    };

    settings = {
      user = {
        name = user.name;
        email = user.email;
      };

      core = {
        editor = "${pkgs.nano}/bin/nano";
      };

      push.autoSetupRemote = true;

      fetch.prune = true;

      merge.conflictstyle = "zdiff3";

      pull.rebase = true;
    };
  };

  home.sessionVariables.GIT_CONFIG_GLOBAL = "${config.xdg.configHome}/git/config";
}
