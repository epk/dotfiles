{
  lib,
  pkgs,
  ...
}:

{
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Permit only the required unfree packages.
  # modules/home/packages.nix uses the 1Password CLI package.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "1password-cli"
    ];

  # Determinate Nix controls the daemon and /etc/nix/nix.conf.
  # Disable Nix management in nix-darwin.
  # Do not set nix.gc, nix.optimise, nix.settings, nix.extraOptions or nix.envVars here.
  # Put daemon settings in /etc/nix/nix.custom.conf.
  nix.enable = false;

  # Apple LibreSSL tools such as /usr/bin/curl read /etc/ssl/cert.pem. The Apple copy trusts roots that Mozilla distrusts.
  # LibreSSL ignores reject rules, so use plain PEM. environment.etc refuses to replace a file that macOS or the MDM rewrites.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    ln -sfn ${pkgs.cacert}/etc/ssl/certs/ca-no-trust-rules-bundle.crt /etc/ssl/cert.pem
    /nix/var/nix/profiles/default/bin/nix-env --profile /nix/var/nix/profiles/system --delete-generations +5
  '';

  # Manual generation removes the nixpkgs source context.
  # This causes an options.json error and a Nix warning.
  documentation.enable = false;

  programs.zsh = {
    enable = true;
    # Home Manager runs compinit from ~/.zshrc.
    enableGlobalCompInit = false;
  };

  environment.shells = [
    pkgs.zsh
  ];

  system.stateVersion = 7;
}
