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
  # Put Tec command paths before the shared paths.
  # Do not run interactive shell hooks from zshenv.
  home.sessionPath = lib.mkBefore [
    "${tec}/toolchain/user_profile/bin"
    "${tecGlobal}/bin"
    "${home}/.local/state/nix/profiles/tec/bin"
    # Tec pnpm 10 puts global command links directly in PNPM_HOME.
    config.programs.pnpm.pnpmHome
  ];

  home.sessionVariables = {
    DEVX_CLAUDE_FEATURE_CONTEXT_WINDOW_250K = "false";
    KUBECONFIG = "${home}/.kube/config:${shopifyKubeconfig}";
  };

  programs.ssh.includes = [
    "~/.config/dev/ssh/include"
  ];

  # Keep the default order. Home Manager runs compinit before this code.
  # /opt/dev/dev.sh requires compdef to register dev and devx completions.
  # Do not use mkBefore here.
  programs.zsh.initContent = ''
    [[ -x "${tecGlobal}/init" ]] && eval "$("${tecGlobal}/init" zsh)"

    [[ -f /opt/dev/dev.sh ]] && source /opt/dev/dev.sh

    update-kubeconfig() {
      gcloud storage cp gs://cluster-info/kubeconfig-dns-endpoints.yml "${shopifyKubeconfig}"
    }
  '';
}
