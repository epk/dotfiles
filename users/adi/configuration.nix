{ config, lib, pkgs, ... }:

{
  home = {
    enableNixpkgsReleaseCheck = true;

    sessionVariables = {
      EDITOR = "nano";
      TMPDIR = "/tmp";  # Prevent nix-shell from using $XDG_RUNTIME_DIR.
    };

    shellAliases = {
      k = "kubectl";
    };

    packages = [
      # Required for the VSCode server
      # Replace the node build in ~/.vscode-server/bin/*/ with
      # a symlink to /etc/profiles/per-user/negz/bin/node*
      pkgs.nodejs-16_x
      pkgs.ripgrep

      # Development tools. Ideally we'd just use a shell.nix for these, but it's
      # tough to get VSCode to respect that.
      pkgs.gnumake
      pkgs.gcc   # For cgo
      pkgs.perl  # For shasum - used in https://github.com/upbound/build
      pkgs.docker
      pkgs.kubectl
      pkgs.kubernetes-helm
      pkgs.kind
      pkgs.gopls
      pkgs.go-outline
      pkgs.golangci-lint
    ];

    sessionPath = [ "$HOME/bin" ];

    stateVersion = "22.05";
  };

  programs = {
    zsh = {
      enable = true;
      enableCompletion = true;
      enableBashCompletion = true;
      enableGlobalCompInit = true;
      syntaxHighlighting.enable = true;
      autosuggestions.enable = true;

      ohMyZsh = {
        enable = true;
        plugins = [ "git" "sudo" "docker" ];
        theme = "agnoster";
      };
    };

    ssh = {
      enable = true;
      forwardAgent = true;
    };

    go = {
      enable = true;
      package = pkgs.unstable.go_1_19;
      goPath = "";
      goBin = "bin";
      goPrivate = [ "github.com/upbound" ];
    };

    jq = {
      enable = true;
    };
  };
}
