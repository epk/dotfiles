# The shared Mac system. hosts/macos-personal and hosts/macos-work import this module.
{
  inputs,
  lib,
  pkgs,
  user,
  ...
}:

{
  imports = [
    ./macos-defaults.nix
    ./packages.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  # Permit only the required unfree packages.
  # modules/darwin/packages.nix and the hosts install these packages.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "1password"
      "1password-cli"
      "appcleaner"
      "claude-code"
      "slack"
      "tuple"
      "vscode"
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

  users.users.${user.username} = {
    home = "/Users/${user.username}";
    uid = 501;
    shell = pkgs.zsh;
  };
  users.knownUsers = [
    user.username
  ];

  system.primaryUser = user.username;

  home-manager = (import ../../lib/hm.nix inputs) // {
    extraSpecialArgs = {
      inherit user;
    };
    # Each host adds its Home Manager profile to this list.
    users.${user.username}.imports = [
      ../home
      ../home/dev.nix
      ../home/darwin.nix
    ];
  };

  system.stateVersion = 7;
}
