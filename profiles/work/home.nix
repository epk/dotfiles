{
  config,
  lib,
  ...
}:

let
  home = config.home.homeDirectory;
in
{
  # Keep Tec-provided commands ahead of the shared paths without running
  # interactive shell hooks from zshenv.
  home.sessionPath = lib.mkBefore [
    "${home}/.local/state/tec/toolchain/user_profile/bin"
    "${home}/.local/state/tec/profiles/base/current/global/bin"
    "${home}/.local/state/nix/profiles/tec/bin"
  ];

  home.sessionVariables = {
    DEVX_CLAUDE_FEATURE_CONTEXT_WINDOW_250K = "false";
    KUBECONFIG = "${home}/.kube/config:${home}/.kube/config.shopify.cloudplatform";
  };

  programs.ssh.includes = [
    "~/.config/dev/ssh/include"
  ];

  programs.zsh.initContent = lib.mkBefore ''
    [[ -x "${home}/.local/state/tec/profiles/base/current/global/init" ]] && eval "$("${home}/.local/state/tec/profiles/base/current/global/init" zsh)"

    [[ -f /opt/dev/dev.sh ]] && source /opt/dev/dev.sh

    update-kubeconfig() {
      gcloud storage cp gs://cluster-info/kubeconfig-dns-endpoints.yml "$HOME/.kube/config.shopify.cloudplatform"
    }
  '';
}
