{
  config,
  pkgs,
  ...
}:

let
  home = config.home.homeDirectory;
  pnpmHome = "${home}/.local/share/pnpm";

  # difftastic owns git's `diff.external` and home-manager permits only one git
  # diff integration, so diff-so-fancy has to be wired up by hand. See the
  # comment on programs.diff-so-fancy in modules/home/git.nix.
  diffSoFancyPager = "${pkgs.diff-so-fancy}/bin/diff-so-fancy | ${pkgs.less}/bin/less --tabs=4 -RFX";
in
{
  home.sessionPath = [
    pnpmHome
    # `uv tool install` and `uv python install` shim here.
    "${home}/.local/bin"
    # GOPATH is $HOME, so `go install` lands here too.
    "${home}/bin"
    "/usr/local/sbin"
  ];

  home.sessionVariables = {
    EDITOR = "nano";
    PNPM_HOME = pnpmHome;
  };

  home.file.".nanorc".text = ''
    include ${pkgs.nanorc}/share/*.nanorc
    set linenumbers
  '';

  programs.go = {
    enable = true;
    env.GOPATH = home;
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      command_timeout = 5000;
      format = "$directory$git_branch$git_status\n$character";
    };
  };

  programs.dircolors.enable = true;

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    icons = "auto";
    git = true;
  };

  programs.bat = {
    enable = true;
    config.style = "plain";
  };

  programs.fd.enable = true;

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    changeDirWidget.command = "fd --type d --hidden --follow --exclude .git";
  };

  programs.try.enable = true;

  programs.nh = {
    enable = true;
    flake = "${home}/src/github.com/epk/dotfiles";
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
    dotDir = home;
    defaultKeymap = "emacs";
    localVariables = {
      # Drop `/` from the default set so ^W deletes one path segment at a time.
      WORDCHARS = "*?_-.[]~=&;!#$%^(){}<>";
    };

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    historySubstringSearch = {
      enable = true;
      searchUpKey = "^[[A";
      searchDownKey = "^[[B";
    };

    shellAliases = {
      k = "kubectl";
      gst = "git status";
      gd = "git diff";
      # Bypass difftastic and page through diff-so-fancy instead.
      gdd = "git -c 'pager.diff=${diffSoFancyPager}' diff --no-ext-diff";
      gco = "git checkout";
      gl = "git pull";
      grb = "git rebase";
      grbi = "git rebase -i";
      grhh = "git reset --hard";
      gp = "git push";
      gpf = "git push --force-with-lease";
      cat = "bat";
    };

    history = {
      path = "${home}/.zsh_history";
      size = 50000;
      save = 10000;
      extended = true;
      ignoreAllDups = true;
      ignoreSpace = true;
      saveNoDups = true;
      findNoDups = true;
      expireDuplicatesFirst = true;
      share = true;
    };

    initContent = ''
      reload!() {
        nh darwin switch "$@" && exec ${pkgs.zsh}/bin/zsh
      }
    '';
  };
}
