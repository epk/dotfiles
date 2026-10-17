{ config, pkgs, ... }:

let
  home = config.home.homeDirectory;

  # difftastic owns diff.external. See programs.diff-so-fancy in modules/home/git.nix.
  diffSoFancyPager = "${pkgs.diff-so-fancy}/bin/diff-so-fancy | ${pkgs.less}/bin/less --tabs=4 -RFX";
in
{
  home.sessionPath = [
    # uv tool install and uv python install put command wrappers here.
    "${home}/.local/bin"
    # GOPATH is $HOME. go install puts programs here.
    "${home}/bin"
    # cargo install puts programs here. rust-bin does not add this path.
    "${home}/.cargo/bin"
  ];

  home.sessionVariables.EDITOR = "nano";

  home.file.".nanorc".text = ''
    include ${pkgs.nanorc}/share/*.nanorc
    set linenumbers
  '';

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
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    changeDirWidget.command = "fd --type d --hidden --follow --exclude .git";
  };

  programs.zoxide.enable = true;

  programs.zsh = {
    enable = true;
    defaultKeymap = "emacs";
    localVariables = {
      # Remove / from WORDCHARS. Ctrl-W then deletes one path segment.
      WORDCHARS = "*?_-.[]~=&;!#$%^(){}<>";
    };

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    historySubstringSearch.enable = true;

    shellAliases = {
      k = "kubectl";
      gst = "git status";
      gd = "git diff";
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
      size = 50000;
      save = 10000;
      extended = true;
      ignoreAllDups = true;
      saveNoDups = true;
      findNoDups = true;
      expireDuplicatesFirst = true;
    };
  };
}
