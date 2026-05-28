{ config, ... }:

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
    EDITOR = "nano";
    PNPM_HOME = "${home}/.local/share/pnpm";
  };

  programs.go = {
    enable = true;
    env.GOPATH = home;
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$character";

      directory = {
        truncation_length = 0;
        truncate_to_repo = false;
        style = "blue";
      };

      git_branch = {
        format = "[$branch]($style) ";
        style = "purple";
      };

      git_status = {
        format = "[$all_status$ahead_behind]($style) ";
        style = "red";
      };

      character = {
        success_symbol = "> ";
        error_symbol = "> ";
      };
    };
  };

  programs.dircolors.enable = true;
  programs.lsd.enable = true;

  programs.bat = {
    enable = true;
    config.style = "plain";
  };

  programs.fd.enable = true;

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
    changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
  };

  programs.try = {
    enable = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
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
      gp = "git push";
      gpf = "git push --force-with-lease";
      cat = "bat";
    };

    history = {
      path = "${home}/.zsh_history";
      size = 50000;
      save = 10000;
      extended = true;
      ignoreDups = true;
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

      export KUBECONFIG="$HOME/.kube/config:$HOME/.kube/config.shopify.cloudplatform"

      update-kubeconfig() {
        gcloud storage cp gs://cluster-info/kubeconfig-dns-endpoints.yml "$HOME/.kube/config.shopify.cloudplatform"
      }
    '';
  };
}
