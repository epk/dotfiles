{
  config,
  lib,
  pkgs,
  ...
}:

let
  caches = import ../../lib/cachix.nix;
  home = config.home.homeDirectory;
  tec = "${home}/.local/state/tec";
  tecGlobal = "${tec}/profiles/base/current/global";
  shopifyKubeconfig = "${home}/.kube/config.shopify.cloudplatform";
  # tec init, dev.sh and brew shellenv export these in the interactive shell.
  launchdVariables = lib.attrNames config.home.sessionVariables ++ [
    "HOMEBREW_CELLAR"
    "HOMEBREW_PREFIX"
    "HOMEBREW_REPOSITORY"
    "INFOPATH"
    "NIX_PATH"
    "NVM_DIR"
    "TECTONIX_TOOLCHAIN_PROFILE_DIR"
    "USING_DEV"
  ];
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
    # Without the opt-out, the devx claude wrapper writes a 250K window to ~/.claude/settings.json.
    DEVX_CLAUDE_FEATURE_CONTEXT_WINDOW_250K = "false";
    CLAUDE_CODE_AUTO_COMPACT_WINDOW = "850000";
    KUBECONFIG = "${home}/.kube/config:${shopifyKubeconfig}";
  };

  # Applications that launchd starts, such as bb, do not read the shell configuration.
  launchd.agents.session-variables = {
    enable = true;
    config = {
      # Unset the earlier values, so that values that append to themselves, such as INFOPATH, do not grow.
      ProgramArguments = [
        "/usr/bin/env"
      ]
      ++ lib.concatMap (name: [
        "-u"
        name
      ]) launchdVariables
      ++ [
        "${pkgs.zsh}/bin/zsh"
        "-l"
        "-i"
        "-c"
        ''
          previous=$(/bin/launchctl getenv KUBECONFIG)
          for name in ${lib.concatStringsSep " " launchdVariables}; do
            if [[ -n ''${(P)name} ]]; then
              /bin/launchctl setenv $name "''${(P)name}"
            else
              /bin/launchctl unsetenv $name
            fi
          done
          # At login, bb can start first. Restart it only then, because a restart stops its threads.
          [[ -n $previous ]] || /bin/launchctl kickstart -k gui/$UID/com.shopify.shop-bb-fy
        ''
      ];
      RunAtLoad = true;
    };
  };

  # Tec supplies git, gh and pnpm earlier in PATH. Do not install second copies.
  programs.gh.enable = lib.mkForce false;
  programs.pnpm.package = null;

  # Shopify dev adds dev/gitconfig to config.local. Do not add a second include for it here.
  programs.git = {
    package = null;
    settings.user.email = "aditya.sharma@shopify.com";
    # Without the Home Manager gh module, Git needs these gh credential helpers.
    settings.credential = lib.genAttrs [ "https://github.com" "https://gist.github.com" ] (_: {
      helper = [
        ""
        "!${tecGlobal}/bin/gh auth git-credential"
      ];
    });
    # Commits in this public repository use the GitHub noreply address.
    includes = [
      {
        condition = "gitdir:${config.programs.nh.flake}/";
        contents.user.email = "9075816+epk@users.noreply.github.com";
      }
    ];
  };

  # Shopify's nix.conf.d/shopify.conf makes this user trusted, so a user setting can add a cache.
  # The Shopify include owns /etc/nix/nix.custom.conf on this Mac.
  home.file.".config/nix/nix.conf".text = ''
    extra-substituters = ${caches.epk.url} ${caches.devenv.url}
    extra-trusted-public-keys = ${caches.epk.publicKey} ${caches.devenv.publicKey}
  '';

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
