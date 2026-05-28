{ config, pkgs, ... }:

let
  home = config.home.homeDirectory;
in
{
  home.sessionPath = [
    "$PNPM_HOME"
    "$HOME/bin"
    "/usr/local/sbin"
  ];

  home.sessionVariables = {
    DEVX_CLAUDE_FEATURE_CONTEXT_WINDOW_250K = "false";
    EDITOR = "nano";
    KUBECONFIG = "${home}/.kube/config:${home}/.kube/config.shopify.cloudplatform";
    PNPM_HOME = "${home}/.local/share/pnpm";
  };

  xdg.configFile."nano/nanorc".text = ''
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
    changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
  };

  programs.try = {
    enable = true;
  };

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
    dotDir = "${config.xdg.configHome}/zsh";
    defaultKeymap = "emacs";

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
      gco = "git checkout";
      grb = "git rebase";
      grbi = "git rebase -i";
      gp = "git push";
      gpf = "git push --force-with-lease";
      cat = "bat";
    };

    history = {
      path = "${config.xdg.stateHome}/zsh/history";
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
      [[ -x "${home}/.local/state/tec/profiles/base/current/global/init" ]] && eval "$("${home}/.local/state/tec/profiles/base/current/global/init" zsh)"

      [[ -f /opt/dev/dev.sh ]] && source /opt/dev/dev.sh

      update-kubeconfig() {
        gcloud storage cp gs://cluster-info/kubeconfig-dns-endpoints.yml "$HOME/.kube/config.shopify.cloudplatform"
      }
    '';
  };
}
