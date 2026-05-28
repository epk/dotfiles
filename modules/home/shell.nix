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

  programs.starship.enable = true;

  programs.zsh = {
    enable = true;
    defaultKeymap = "emacs";

    history = {
      path = "${home}/.zsh_history";
      size = 50000;
      save = 10000;
      extended = true;
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
    };

    initContent = ''
      [[ -f /opt/dev/dev.sh ]] && source /opt/dev/dev.sh

      export KUBECONFIG="$HOME/.kube/config:$HOME/.kube/config.shopify.cloudplatform"

      update-kubeconfig() {
        gcloud storage cp gs://cluster-info/kubeconfig-dns-endpoints.yml "$HOME/.kube/config.shopify.cloudplatform"
      }
    '';
  };
}
