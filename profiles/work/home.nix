{
  config,
  lib,
  ...
}:

let
  home = config.home.homeDirectory;
  tec = "${home}/.local/state/tec";
  tecGlobal = "${tec}/profiles/base/current/global";
  shopifyKubeconfig = "${home}/.kube/config.shopify.cloudplatform";
in
{
  # Keep Tec-provided commands ahead of the shared paths without running
  # interactive shell hooks from zshenv.
  home.sessionPath = lib.mkBefore [
    "${tec}/toolchain/user_profile/bin"
    "${tecGlobal}/bin"
    "${home}/.local/state/nix/profiles/tec/bin"
  ];

  home.sessionVariables = {
    DEVX_CLAUDE_FEATURE_CONTEXT_WINDOW_250K = "false";
    KUBECONFIG = "${home}/.kube/config:${shopifyKubeconfig}";
  };

  programs.ssh.includes = [
    "~/.config/dev/ssh/include"
  ];

  # Must stay at the default order: /opt/dev/dev.sh only registers the `dev` and
  # `devx` completions if `compdef` already exists, and home-manager runs
  # compinit mid-.zshrc. mkBefore would hoist this above compinit and silently
  # drop them.
  programs.zsh.initContent = ''
    [[ -x "${tecGlobal}/init" ]] && eval "$("${tecGlobal}/init" zsh)"

    [[ -f /opt/dev/dev.sh ]] && source /opt/dev/dev.sh

    update-kubeconfig() {
      gcloud storage cp gs://cluster-info/kubeconfig-dns-endpoints.yml "${shopifyKubeconfig}"
    }
  '';
}
